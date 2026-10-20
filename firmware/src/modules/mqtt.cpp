#include "mqtt.h"

#include <Arduino.h>
#include <PubSubClient.h>
#include <WiFi.h>

#include "retry_interval.h"
#include "terminal_settings.h"

namespace {
WiFiClient transport;
PubSubClient client(transport);
RetryInterval wifiRetry(WIFI_RETRY_MS);
RetryInterval mqttRetry(MQTT_RETRY_MS);

void onMessage(char* topic, uint8_t* payload, unsigned int length) {
  (void)payload;
  // Sem parser v1, validacao, atuacao ou ACK. Nao logar credenciais/payloads.
  Serial.printf("[mqtt] mensagem recebida em %s (%u bytes); ignorada no esqueleto\n",
                topic, length);
}

void startWiFi() {
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  Serial.println("[wifi] conectando");
}
}

namespace terminal_mqtt {
void begin() {
  WiFi.persistent(false);
  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(false);  // Uma unica politica de retentativas, abaixo.
  // Arduino-ESP32 2.x: setTimeout recebe segundos e tambem limita connect().
  transport.setTimeout(MQTT_TCP_TIMEOUT_SECONDS);
  client.setServer(MQTT_HOST, MQTT_PORT);
  client.setSocketTimeout(MQTT_SOCKET_TIMEOUT_SECONDS);
  client.setCallback(onMessage);
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
    if (!client.subscribe(terminal_settings::commandsTopic, 1)) {
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
}
