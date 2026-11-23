#include "mqtt.h"

#include <Arduino.h>
#include <ArduinoJson.h>
#include <MQTTClient.h>
#include <WiFi.h>

#include "clock_policy.h"
#include "iso8601.h"
#include "nfc_scan.h"
#include "retry_interval.h"
#include "terminal_settings.h"

#if MQTT_USE_TLS
#include <WiFiClientSecure.h>

#include "mqtt_ca.h"
// O core 2.0.17 ja recusa a conexao sem CA (ssl_client.cpp); recusar tambem na
// compilacao evita um firmware de producao que nunca conecta.
static_assert(sizeof(mqtt_ca::kRootPem) > 64, "MQTT_USE_TLS=1 exige um CA em include/mqtt_ca.h");
#endif

namespace {

#if MQTT_USE_TLS
WiFiClientSecure transport;
#else
WiFiClient transport;
#endif
MQTTClient client(512);
RetryInterval wifiRetry(WIFI_RETRY_MS);
RetryInterval mqttRetry(MQTT_RETRY_MS);

terminal_command::Handler handler;
terminal_mqtt::Actuator actuator = nullptr;
terminal_mqtt::Clock clockSource = nullptr;
qr_token::State qrState;

// Nao publicar QoS 1 de dentro do callback: a espera pelo PUBACK pode
// reentrar no cliente. Guardar comandos e processar fora de client.loop().
char commandQueue[8][513] = {};
unsigned int commandLengths[8] = {};
uint8_t queueHead = 0;
uint8_t queueCount = 0;

// Antes disto o SNTP nao respondeu: sem hora confiavel nao da para aprovar um
// prazo, entao o comando e recusado (fail-closed) em vez de aberto.
constexpr unsigned int kPayloadCapacity = 512;
constexpr size_t kAckCapacity = 320;
char pendingAck[kAckCapacity] = {};
size_t pendingAckLength = 0;

uint64_t clockNow() { return clockSource == nullptr ? 0 : clockSource(); }

void copyText(char* destination, size_t size, const char* source) {
  strncpy(destination, source, size - 1);
  destination[size - 1] = '\0';
}

void makeMessageId(char* out, size_t size) {
  static const char kHex[] = "0123456789abcdef";
  if (size < 37) {
    out[0] = '\0';
    return;
  }

  uint8_t bytes[16];
  for (uint8_t i = 0; i < 16; i += 4) {
    const uint32_t random = esp_random();
    bytes[i] = static_cast<uint8_t>(random >> 24);
    bytes[i + 1] = static_cast<uint8_t>(random >> 16);
    bytes[i + 2] = static_cast<uint8_t>(random >> 8);
    bytes[i + 3] = static_cast<uint8_t>(random);
  }
  bytes[6] = static_cast<uint8_t>((bytes[6] & 0x0F) | 0x40);  // UUID v4
  bytes[8] = static_cast<uint8_t>((bytes[8] & 0x3F) | 0x80);

  size_t position = 0;
  for (uint8_t i = 0; i < 16; ++i) {
    if (i == 4 || i == 6 || i == 8 || i == 10) out[position++] = '-';
    out[position++] = kHex[bytes[i] >> 4];
    out[position++] = kHex[bytes[i] & 0x0F];
  }
  out[position] = '\0';
}

void queueAck(const terminal_command::Ack& ack) {
  char messageId[37];
  makeMessageId(messageId, sizeof messageId);

  char timestamp[32] = {};
  iso8601::fromEpoch(clockNow(), timestamp, sizeof timestamp);

  JsonDocument document;
  document["v"] = 1;
  document["messageId"] = messageId;
  document["terminalId"] = terminal_settings::id;
  document["timestamp"] = timestamp;
  document["commandId"] = ack.commandId;
  document["status"] = ack.status;
  if (ack.reason != nullptr) document["reason"] = ack.reason;

  pendingAckLength = serializeJson(document, pendingAck, sizeof pendingAck);
  if (pendingAckLength == 0 || pendingAckLength >= sizeof pendingAck) {
    pendingAckLength = 0;
    Serial.println("[mqtt] ack excedeu o buffer; descartado");
    return;
  }
}

void readCommand(const uint8_t* payload, unsigned int length) {
  if (length == 0 || length > kPayloadCapacity) {
    Serial.printf("[mqtt] comando descartado: tamanho %u\n", length);
    return;
  }

  JsonDocument document;
  const DeserializationError error = deserializeJson(document, payload, length);
  if (error) {
    Serial.printf("[mqtt] comando descartado: JSON invalido (%s)\n", error.c_str());
    return;
  }
  const JsonObjectConst root = document.as<JsonObjectConst>();
  if (root.isNull()) {
    Serial.println("[mqtt] comando descartado: payload nao e objeto");
    return;
  }

  terminal_command::Parsed parsed;
  parsed.version = root["v"] | 0;
  copyText(parsed.terminalId, sizeof parsed.terminalId, root["terminalId"] | "");
  copyText(parsed.commandId, sizeof parsed.commandId, root["commandId"] | "");
  const char* action = root["action"] | "";
  if (strcmp(action, "open") == 0) {
    parsed.action = terminal_command::Action::open;
    parsed.actionValid = true;
  } else if (strcmp(action, "deny") == 0) {
    parsed.action = terminal_command::Action::deny;
    parsed.actionValid = true;
  }
  parsed.expiresAtValid = iso8601::toEpoch(root["expiresAt"] | "", parsed.expiresAt);

  const uint64_t now = clockNow();
  const terminal_command::Ack* ack = handler.handle(parsed, now, clock_policy::reliable(now));
  if (ack == nullptr) {
    Serial.println("[mqtt] comando sem commandId; descartado");
    return;
  }
  Serial.printf("[mqtt] comando %s: %s\n", ack->commandId, ack->status);
  queueAck(*ack);
}

void readQr(const uint8_t* payload, unsigned int length) {
  if (length == 0 || length > kPayloadCapacity) return;

  JsonDocument document;
  if (deserializeJson(document, payload, length)) return;
  const JsonObjectConst root = document.as<JsonObjectConst>();
  if (root.isNull() || (root["v"] | 0) != 1) return;
  if (strcmp(root["terminalId"] | "", terminal_settings::id) != 0) return;

  const char* token = root["token"] | "";
  const size_t tokenLength = strlen(token);
  uint64_t expiresAt = 0;
  if (tokenLength == 0 || tokenLength >= sizeof qrState.token ||
      !iso8601::toEpoch(root["expiresAt"] | "", expiresAt)) {
    // Payload ruim nao apaga o ultimo QR valido: o display continua mostrando o anterior.
    Serial.println("[mqtt] qr descartado: token ou expiresAt invalido");
    return;
  }
  copyText(qrState.token, sizeof qrState.token, token);
  qrState.expiresAt = expiresAt;
  qrState.hasToken = true;
  Serial.printf("[mqtt] qr recebido (expira em %llu)\n",
                static_cast<unsigned long long>(expiresAt));
}

void onMessage(MQTTClient*, char* topic, char* payload, int length) {
  if (length <= 0 || length > static_cast<int>(kPayloadCapacity)) return;
  if (strcmp(topic, terminal_settings::commandsTopic) == 0) {
    if (queueCount == 8) {
      Serial.println("[mqtt] fila de comandos cheia; comando descartado");
      return;
    }
    const uint8_t slot = (queueHead + queueCount) % 8;
    memcpy(commandQueue[slot], payload, length);
    commandLengths[slot] = static_cast<unsigned int>(length);
    ++queueCount;
    return;
  }
  if (strcmp(topic, terminal_settings::qrTopic) == 0)
    readQr(reinterpret_cast<const uint8_t*>(payload), static_cast<unsigned int>(length));
}

void startWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.println("[wifi] conectando");
}

}  // namespace

namespace terminal_mqtt {

void setActuator(Actuator value) {
  actuator = value;
  handler.configure(terminal_settings::id, value);
}

void setClock(Clock clock) { clockSource = clock; }

void begin() {
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(false);  // Uma unica politica de retentativas, abaixo.
  // Arduino-ESP32 2.x: setTimeout recebe segundos e tambem limita connect().
  transport.setTimeout(MQTT_TCP_TIMEOUT_SECONDS);
#if MQTT_USE_TLS
  // O CA vale para toda conexao (inclusive reconexoes); a validacao nunca e desligada
  // (o CI proibe o metodo que aceita qualquer certificado).
  transport.setCACert(mqtt_ca::kRootPem);
  transport.setHandshakeTimeout(MQTT_HANDSHAKE_TIMEOUT_SECONDS);
#endif
  client.begin(MQTT_HOST, MQTT_PORT, transport);
  client.setTimeout(MQTT_SOCKET_TIMEOUT_SECONDS * 1000);
  client.onMessageAdvanced(onMessage);
  handler.configure(terminal_settings::id, actuator);
  if (wifiRetry.ready(millis())) startWiFi();
}

void update(bool allowBlocking) {
  // QoS 1 e manutencao MQTT podem esperar pela rede; nunca atrasar o servo.
  if (!allowBlocking) return;
  const uint32_t now = millis();
  if (WiFi.status() != WL_CONNECTED) {
    client.disconnect();
    transport.stop();
    if (wifiRetry.ready(now)) {
      WiFi.disconnect();
      startWiFi();
    }
    return;
  }

  if (!client.connected()) {
#if MQTT_USE_TLS
    // Sem hora UTC confiavel todo certificado parece vencido ou ainda invalido:
    // esperar o SNTP sem gastar tentativa nem segurar o loop num handshake inutil.
    static bool waitingForClock = false;
    if (!clock_policy::reliable(clockNow())) {
      if (!waitingForClock) Serial.println("[mqtt] tls aguardando hora (sntp)");
      waitingForClock = true;
      return;
    }
    waitingForClock = false;
#endif
    if (!mqttRetry.ready(now)) return;

#if MQTT_USE_TLS
    const uint32_t connectStartedAt = millis();
#endif
    // Credenciais vazias no Mosquitto dev; nao enviar username vazio.
    const bool established = MQTT_USERNAME[0] == '\0'
        ? client.connect(terminal_settings::id)
        : client.connect(terminal_settings::id, MQTT_USERNAME, MQTT_PASSWORD);
    if (!established) {
#if MQTT_USE_TLS
      // O motivo TLS (certificado, hostname, handshake) vem do transporte,
      // separado do erro MQTT. Nao imprime credenciais nem payload.
      char tlsError[96] = {};
      const int tlsCode = transport.lastError(tlsError, sizeof tlsError);
      Serial.printf("[mqtt] conexao falhou (estado=%d, tls=%d %s); nova tentativa depois\n",
                    static_cast<int>(client.lastError()), tlsCode, tlsError);
      transport.stop();  // Libera o contexto mbedTLS antes da proxima tentativa.
#else
      Serial.printf("[mqtt] conexao falhou (estado=%d); nova tentativa depois\n",
                    static_cast<int>(client.lastError()));
#endif
      return;
    }
    if (!client.subscribe(terminal_settings::commandsTopic, 1) ||
        !client.subscribe(terminal_settings::qrTopic, 1)) {
      Serial.println("[mqtt] inscricao falhou; reconectar depois");
      client.disconnect();
      transport.stop();
      return;
    }
    // MQTTClient espera SUBACK; so anunciamos conectado apos as inscricoes.
    Serial.println("[mqtt] conectado e inscrito nos comandos");
#if MQTT_USE_TLS
    // Medidas para a evidencia da DT-06: custo do handshake (bloqueia o loop) e heap livre.
    Serial.printf("[mqtt] tls ok em %u ms, heap livre %u B\n",
                  static_cast<unsigned>(millis() - connectStartedAt),
                  static_cast<unsigned>(ESP.getFreeHeap()));
#endif
  }
  client.loop();
  if (pendingAckLength != 0) {
    if (!client.publish(terminal_settings::acksTopic, pendingAck,
                        static_cast<int>(pendingAckLength), false, 1)) {
      Serial.println("[mqtt] falha ao publicar ack");
    }
    pendingAckLength = 0;
    if (!client.connected()) return;
  }
  if (queueCount != 0) {
    // Retirar antes de publicar ACK: publicacoes podem receber novos comandos.
    char payload[513];
    const unsigned int length = commandLengths[queueHead];
    memcpy(payload, commandQueue[queueHead], length);
    queueHead = (queueHead + 1) % 8;
    --queueCount;
    readCommand(reinterpret_cast<const uint8_t*>(payload), length);
  }
}

bool connected() {
  return WiFi.status() == WL_CONNECTED && client.connected();
}

qr_token::State qr() { return qrState; }

bool publishNfc(const char* uid) {
  const uint64_t now = clockNow();
  if (!connected() || !clock_policy::reliable(now) || !nfc_scan::validUid(uid)) return false;
  char messageId[37];
  char timestamp[32] = {};
  makeMessageId(messageId, sizeof messageId);
  iso8601::fromEpoch(now, timestamp, sizeof timestamp);
  JsonDocument document;
  document["v"] = 1;
  document["messageId"] = messageId;
  document["terminalId"] = terminal_settings::id;
  document["timestamp"] = timestamp;
  document["type"] = "nfc_read";
  document["uid"] = uid;
  char payload[320];
  const size_t length = serializeJson(document, payload, sizeof payload);
  if (length == 0 || length >= sizeof payload) return false;
  // Sem retain, sem fila offline ou renovacao artificial do timestamp (US-25).
  return client.publish(terminal_settings::accessEventsTopic, payload,
                        static_cast<int>(length), false, 1);
}

}  // namespace terminal_mqtt
