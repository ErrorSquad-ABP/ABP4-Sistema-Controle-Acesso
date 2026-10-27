#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "Arduino.h"
#include "PubSubClient.h"
#include "modules/mqtt.h"

uint32_t testNow = 0;
TestSerial Serial;
TestWiFi WiFi;
TestBroker broker;
uint32_t tcpTimeoutSeconds = 0;

int main() {
  terminal_mqtt::begin();
  assert(WiFi.beginCalls == 1);
  assert(tcpTimeoutSeconds == 1);
  terminal_mqtt::update();
  assert(broker.connectCalls == 0);  // Nao tentar MQTT sem WiFi.
  testNow = 4999;
  terminal_mqtt::update();
  assert(WiFi.beginCalls == 1);
  testNow = 5000;
  terminal_mqtt::update();
  assert(WiFi.beginCalls == 2);

  WiFi.currentStatus = WL_CONNECTED;
  terminal_mqtt::update();
  assert(broker.connectCalls == 1);
  assert(!terminal_mqtt::connected());
  testNow = 9999;
  terminal_mqtt::update();
  assert(broker.connectCalls == 1);

  testNow = 10000;
  broker.connectResult = true;
  terminal_mqtt::update();
  assert(terminal_mqtt::connected());
  assert(strcmp(broker.clientId, "terminal-dev-01") == 0);
  assert(strcmp(broker.subscribedTopics[0], "terminals/terminal-dev-01/commands") == 0);
  assert(strcmp(broker.subscribedTopics[1], "terminals/terminal-dev-01/qr") == 0);
  assert(broker.qos == 1);
  assert(broker.subscriptions == 2);
  terminal_mqtt::update();
  assert(broker.connectCalls == 2);
  assert(broker.loopCalls > 0);

  WiFi.currentStatus = WL_DISCONNECTED;
  terminal_mqtt::update();
  assert(!terminal_mqtt::connected());
  assert(broker.connectCalls == 2);

  WiFi.currentStatus = WL_CONNECTED;
  testNow = 15000;
  broker.subscribeResult = false;
  terminal_mqtt::update();
  assert(!terminal_mqtt::connected());  // Inscricao falhou: reconectar depois.
  assert(broker.subscriptions == 3);
  testNow = 20000;
  broker.subscribeResult = true;
  terminal_mqtt::update();
  assert(terminal_mqtt::connected());
  assert(broker.subscriptions == 5);

  puts("mqtt: offline, retentativas, inscricao e reconexao OK");
}
