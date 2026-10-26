#include "mqtt.h"

#include <Arduino.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <WiFi.h>

#include "iso8601.h"
#include "retry_interval.h"
#include "terminal_settings.h"

namespace {

WiFiClient transport;
PubSubClient client(transport);
RetryInterval wifiRetry(WIFI_RETRY_MS);
RetryInterval mqttRetry(MQTT_RETRY_MS);

terminal_command::Handler handler;
terminal_mqtt::Actuator actuator = nullptr;
terminal_mqtt::Clock clockSource = nullptr;
qr_token::State qrState;

// Antes disto o SNTP nao respondeu: sem hora confiavel nao da para aprovar um
// prazo, entao o comando e recusado (fail-closed) em vez de aberto.
constexpr uint64_t kClockValidFrom = 1735689600ULL;  // 2025-01-01T00:00:00Z
constexpr unsigned int kPayloadCapacity = 512;
constexpr size_t kAckCapacity = 320;

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

void publishAck(const terminal_command::Ack& ack) {
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

  char payload[kAckCapacity];
  const size_t length = serializeJson(document, payload, sizeof payload);
  if (length == 0 || length >= sizeof payload) {
    Serial.println("[mqtt] ack excedeu o buffer; descartado");
    return;
  }
  if (!client.publish(terminal_settings::acksTopic, reinterpret_cast<const uint8_t*>(payload),
                      static_cast<unsigned int>(length), false)) {
    Serial.println("[mqtt] falha ao publicar ack");
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
  const terminal_command::Ack* ack = handler.handle(parsed, now, now >= kClockValidFrom);
  if (ack == nullptr) {
    Serial.println("[mqtt] comando sem commandId; descartado");
    return;
  }
  Serial.printf("[mqtt] comando %s: %s\n", ack->commandId, ack->status);
  publishAck(*ack);
}

void readQr(const uint8_t* payload, unsigned int length) {
  if (length == 0 || length > kPayloadCapacity) return;

  JsonDocument document;
  if (deserializeJson(document, payload, length)) return;
  const JsonObjectConst root = document.as<JsonObjectConst>();
  if (root.isNull() || (root["v"] | 0) != 1) return;
  if (strcmp(root["terminalId"] | "", terminal_settings::id) != 0) return;

  const char* token = root["token"] | "";
  uint64_t expiresAt = 0;
  if (token[0] == '\0' || !iso8601::toEpoch(root["expiresAt"] | "", expiresAt)) {
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

void onMessage(char* topic, uint8_t* payload, unsigned int length) {
  if (strcmp(topic, terminal_settings::commandsTopic) == 0) {
    readCommand(payload, length);
    return;
  }
  if (strcmp(topic, terminal_settings::qrTopic) == 0) readQr(payload, length);
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
  client.setServer(MQTT_HOST, MQTT_PORT);
  client.setSocketTimeout(MQTT_SOCKET_TIMEOUT_SECONDS);
  client.setBufferSize(kPayloadCapacity);
  client.setCallback(onMessage);
  handler.configure(terminal_settings::id, actuator);
  if (wifiRetry.ready(millis())) startWiFi();
}

void update() {
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
    if (!mqttRetry.ready(now)) return;

    // Credenciais vazias no Mosquitto dev; nao enviar username vazio.
    const bool established = MQTT_USERNAME[0] == '\0'
        ? client.connect(terminal_settings::id)
        : client.connect(terminal_settings::id, MQTT_USERNAME, MQTT_PASSWORD);
    if (!established) {
      Serial.printf("[mqtt] conexao falhou (estado=%d); nova tentativa depois\n",
                    client.state());
      return;
    }
    if (!client.subscribe(terminal_settings::commandsTopic, 1) ||
        !client.subscribe(terminal_settings::qrTopic, 1)) {
      Serial.println("[mqtt] inscricao falhou; reconectar depois");
      client.disconnect();
      transport.stop();
      return;
    }
    // subscribe() confirma o envio; o broker dev precisa aceitar a inscricao.
    Serial.println("[mqtt] conectado e inscrito nos comandos");
  }
  client.loop();
}

bool connected() {
  return WiFi.status() == WL_CONNECTED && client.connected();
}

qr_token::State qr() { return qrState; }

}  // namespace terminal_mqtt
