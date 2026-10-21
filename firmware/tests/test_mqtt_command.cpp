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

namespace {

const char* kCommandsTopic = "terminals/terminal-dev-01/commands";
const char* kOpenCommand =
    R"({"v":1,"messageId":"5d7c9a10-2b3e-4f61-a8d4-9e0b1c2d3f45","terminalId":"terminal-dev-01","timestamp":"2026-10-19T19:30:03.400Z","commandId":"c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c01","expiresAt":"2026-10-19T19:30:13.400Z","action":"open","reason":"nfc_authorized"})";

uint64_t testClock = 1792438213ULL;  // 2026-10-19T19:30:13Z
uint64_t fakeClock() { return testClock; }

int actions = 0;
terminal_command::Action lastAction = terminal_command::Action::deny;

bool actuator(terminal_command::Action action) {
  ++actions;
  lastAction = action;
  return true;
}

void deliver(const char* json, const char* topic = kCommandsTopic) {
  char payload[600];
  const size_t length = strlen(json);
  memcpy(payload, json, length + 1);
  broker.callback(const_cast<char*>(topic), reinterpret_cast<uint8_t*>(payload),
                  static_cast<unsigned int>(length));
}

void expectPublish(const char* fragment) {
  assert(strstr(broker.publishedPayload, fragment) != nullptr);
}

// zod valida UUID v4 no backend: messageId precisa ter versao e variante certas.
void expectUuidMessageId() {
  const char* value = strstr(broker.publishedPayload, "\"messageId\":\"");
  assert(value != nullptr);
  value += strlen("\"messageId\":\"");
  char id[37];
  memcpy(id, value, sizeof id - 1);
  id[sizeof id - 1] = '\0';
  assert(id[8] == '-' && id[13] == '-' && id[18] == '-' && id[23] == '-');
  assert(id[14] == '4');
  assert(strchr("89ab", id[19]) != nullptr);
  assert(value[36] == '"');
}

}  // namespace

int main() {
  terminal_mqtt::setClock(fakeClock);
  terminal_mqtt::setActuator(actuator);
  WiFi.currentStatus = WL_CONNECTED;
  broker.connectResult = true;

  terminal_mqtt::begin();
  terminal_mqtt::update();
  assert(broker.subscriptions == 1);
  assert(broker.callback != nullptr);
  assert(broker.bufferSize >= 512);

  // Comando dentro do prazo: aciona uma vez e responde `executed`.
  deliver(kOpenCommand);
  assert(actions == 1);
  assert(lastAction == terminal_command::Action::open);
  assert(broker.publishCalls == 1);
  assert(strcmp(broker.publishedTopic, "terminals/terminal-dev-01/acks") == 0);
  assert(broker.publishedRetained == false);
  expectPublish("\"v\":1");
  expectPublish("\"terminalId\":\"terminal-dev-01\"");
  expectPublish("\"timestamp\":\"2026-10-19T19:30:13.000Z\"");
  expectPublish("\"commandId\":\"c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c01\"");
  expectPublish("\"status\":\"executed\"");
  expectUuidMessageId();
  assert(strstr(broker.publishedPayload, "reason") == nullptr);

  // Reentrega do mesmo commandId: responde o ACK anterior e nao aciona de novo.
  deliver(kOpenCommand);
  assert(actions == 1);
  assert(broker.publishCalls == 2);
  expectPublish("\"status\":\"executed\"");
  expectPublish("\"reason\":\"duplicate\"");

  // Tópico diferente do inscrito e ignorado.
  deliver(kOpenCommand, "terminals/terminal-dev-01/qr");
  assert(actions == 1);
  assert(broker.publishCalls == 2);

  // Comando vencido: ACK `expired`, sem acionar servo.
  deliver(
      R"({"v":1,"messageId":"9f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10","terminalId":"terminal-dev-01","timestamp":"2026-10-19T19:29:50.000Z","commandId":"a1b2c3d4-0000-4000-8000-000000000001","expiresAt":"2026-10-19T19:29:55.000Z","action":"open"})");
  assert(actions == 1);
  assert(broker.publishCalls == 3);
  expectPublish("\"commandId\":\"a1b2c3d4-0000-4000-8000-000000000001\"");
  expectPublish("\"status\":\"expired\"");

  // `deny` nao move a cancela, mas executa o feedback de negado.
  deliver(
      R"({"v":1,"messageId":"0b8e5f43-7c1a-4b6e-8d92-3a4f9c6e7d10","terminalId":"terminal-dev-01","timestamp":"2026-10-19T19:30:03.400Z","commandId":"a1b2c3d4-0000-4000-8000-000000000002","expiresAt":"2026-10-19T19:30:13.400Z","action":"deny","reason":"nfc_denied"})");
  assert(actions == 2);
  assert(lastAction == terminal_command::Action::deny);
  expectPublish("\"status\":\"executed\"");

  // action fora do contrato e recusada.
  deliver(
      R"({"v":1,"messageId":"0b8e5f43-7c1a-4b6e-8d92-3a4f9c6e7d11","terminalId":"terminal-dev-01","timestamp":"2026-10-19T19:30:03.400Z","commandId":"a1b2c3d4-0000-4000-8000-000000000003","expiresAt":"2026-10-19T19:30:13.400Z","action":"unlock"})");
  assert(actions == 2);
  expectPublish("\"status\":\"rejected\"");
  expectPublish("\"reason\":\"unsupported_action\"");

  // terminalId diferente do topico e recusado.
  deliver(
      R"({"v":1,"messageId":"0b8e5f43-7c1a-4b6e-8d92-3a4f9c6e7d12","terminalId":"terminal-99","timestamp":"2026-10-19T19:30:03.400Z","commandId":"a1b2c3d4-0000-4000-8000-000000000004","expiresAt":"2026-10-19T19:30:13.400Z","action":"open"})");
  assert(actions == 2);
  expectPublish("\"reason\":\"terminal_mismatch\"");

  // Sem relogio confiavel o terminal nao abre a porta.
  testClock = 0;
  deliver(
      R"({"v":1,"messageId":"0b8e5f43-7c1a-4b6e-8d92-3a4f9c6e7d13","terminalId":"terminal-dev-01","timestamp":"2026-10-19T19:30:03.400Z","commandId":"a1b2c3d4-0000-4000-8000-000000000005","expiresAt":"2026-10-19T19:30:13.400Z","action":"open"})");
  assert(actions == 2);
  expectPublish("\"reason\":\"clock_unsynced\"");
  testClock = 1792438213ULL;

  // Payload invalido ou sem commandId: descartado sem ACK.
  int publishesBefore = broker.publishCalls;
  deliver("smoke-us07");
  deliver(
      R"({"v":1,"terminalId":"terminal-dev-01","expiresAt":"2026-10-19T19:30:13.400Z","action":"open"})");
  assert(broker.publishCalls == publishesBefore);
  assert(actions == 2);

  puts("mqtt: JSON v1, prazo, dedup, ACK e recusas OK");
}
