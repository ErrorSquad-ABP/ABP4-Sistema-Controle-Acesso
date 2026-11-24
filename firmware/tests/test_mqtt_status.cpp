#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "Arduino.h"
#include "MQTTClient.h"
#include "modules/mqtt.h"

uint32_t testNow = 0;
TestSerial Serial;
TestWiFi WiFi;
TestBroker broker;
uint32_t tcpTimeoutSeconds = 0;

namespace {

bool contains(const char* text, const char* part) { return strstr(text, part) != nullptr; }

}  // namespace

int main() {
  terminal_mqtt::begin();
  WiFi.currentStatus = WL_CONNECTED;
  broker.connectResult = true;
  terminal_mqtt::update();

  assert(terminal_mqtt::connected());
  // LWT registrado antes do connect: offline, retained e QoS 1.
  assert(broker.willCalls == 1);
  assert(strcmp(broker.willTopic, "terminals/terminal-dev-01/status") == 0);
  assert(broker.willRetained);
  assert(broker.willQos == 1);
  assert(contains(broker.willPayload, "\"state\":\"offline\""));
  assert(contains(broker.willPayload, "\"terminalId\":\"terminal-dev-01\""));

  // Ao conectar, anuncia online retained QoS 1 com a versao do firmware.
  assert(strcmp(broker.publishedTopic, "terminals/terminal-dev-01/status") == 0);
  assert(broker.publishedRetained);
  assert(broker.publishedQos == 1);
  assert(contains(broker.publishedPayload, "\"state\":\"online\""));
  assert(contains(broker.publishedPayload, "\"firmware\":\"abp4-1.0\""));

  // Heartbeat de 30 s: nada antes, uma publicacao ao completar a janela.
  const int afterConnect = broker.publishCalls;
  testNow += 29999;
  terminal_mqtt::update();
  assert(broker.publishCalls == afterConnect);
  testNow += 1;
  terminal_mqtt::update();
  assert(broker.publishCalls == afterConnect + 1);
  assert(contains(broker.publishedPayload, "\"state\":\"online\""));

  // Queda e reconexao: o LWT e registrado de novo e o online sai na hora.
  broker.online = false;
  testNow += 5000;
  terminal_mqtt::update();
  assert(terminal_mqtt::connected());
  assert(broker.willCalls == 2);
  assert(strcmp(broker.publishedTopic, "terminals/terminal-dev-01/status") == 0);
  assert(contains(broker.publishedPayload, "\"state\":\"online\""));

  puts("mqtt status: LWT offline, online retained e heartbeat de 30 s OK");
}
