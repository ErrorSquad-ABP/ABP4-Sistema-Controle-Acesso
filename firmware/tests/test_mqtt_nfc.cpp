#include <assert.h>
#include <stdio.h>
#include <string.h>
#include <ArduinoJson.h>
#include "Arduino.h"
#include "MQTTClient.h"
#include "modules/mqtt.h"

uint32_t testNow = 0;
TestSerial Serial;
TestWiFi WiFi;
TestBroker broker;
uint32_t tcpTimeoutSeconds = 0;
uint64_t utc = 1792438213ULL;
uint64_t clockSource() { return utc; }

int main() {
  terminal_mqtt::setClock(clockSource);
  terminal_mqtt::begin();
  assert(!terminal_mqtt::publishNfc("04A1B2C3"));
  assert(broker.publishCalls == 0);
  WiFi.currentStatus = WL_CONNECTED;
  broker.connectResult = true;
  terminal_mqtt::update();
  utc = 0;
  assert(!terminal_mqtt::publishNfc("04A1B2C3"));
  assert(broker.publishCalls == 0);
  utc = 1792438213ULL;
  assert(!terminal_mqtt::publishNfc("04a1b2c3"));
  assert(!terminal_mqtt::publishNfc(nullptr));
  assert(!terminal_mqtt::publishNfc("04"));
  assert(terminal_mqtt::publishNfc("04A1B2C3"));
  assert(strcmp(broker.publishedTopic, "terminals/terminal-dev-01/access-events") == 0);
  assert(!broker.publishedRetained);
  assert(broker.publishedQos == 1);
  JsonDocument doc;
  assert(!deserializeJson(doc, broker.publishedPayload));
  assert(doc["v"] == 1);
  assert(doc["terminalId"] == "terminal-dev-01");
  assert(doc["type"] == "nfc_read");
  assert(doc["timestamp"] == "2026-10-19T19:30:13.000Z");
  assert(doc["uid"] == "04A1B2C3");
  const char* id = doc["messageId"];
  assert(strlen(id) == 36 && id[14] == '4' && strchr("89ab", id[19]));
  char previous[37];
  strcpy(previous, id);
  assert(terminal_mqtt::publishNfc("00112233445566"));
  assert(!deserializeJson(doc, broker.publishedPayload));
  assert(strcmp(previous, doc["messageId"].as<const char*>()) != 0);
  broker.publishResult = false;
  assert(!terminal_mqtt::publishNfc("00112233445566778899"));
  puts("mqtt NFC: envelope v1, QoS 1, UTC, offline e falha PUBACK OK");
}
