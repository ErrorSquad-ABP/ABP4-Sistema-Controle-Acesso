// Compilar com -DMQTT_USE_TLS=1 e tests/fakes antes de include/ (o mqtt_ca.h de teste
// substitui o PEM real). Cobre DT-06: CA configurado, handshake limitado, hora
// confiavel antes de conectar e falha fechada quando o certificado e recusado.
#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "Arduino.h"
#include "PubSubClient.h"
#include "WiFiClientSecure.h"
#include "modules/mqtt.h"
#include "mqtt_ca.h"

uint32_t testNow = 0;
TestSerial Serial;
TestWiFi WiFi;
TestBroker broker;
TestTls tls;
TestEsp ESP;
uint32_t tcpTimeoutSeconds = 0;

namespace {

uint64_t testClock = 0;  // 0 = SNTP ainda nao respondeu
uint64_t fakeClock() { return testClock; }

}  // namespace

int main() {
  terminal_mqtt::setClock(fakeClock);
  terminal_mqtt::begin();

  // O CA entra antes de qualquer tentativa de conexao e a validacao nunca e desligada.
  assert(tls.caCalls == 1);
  assert(tls.caCert != nullptr && strcmp(tls.caCert, mqtt_ca::kRootPem) == 0);
  assert(tls.handshakeTimeoutSeconds == 5);
  assert(tls.insecureCalls == 0);
  assert(broker.connectCalls == 0);

  // Com WiFi mas sem hora confiavel nenhum certificado parece valido: nem tenta.
  WiFi.currentStatus = WL_CONNECTED;
  for (testNow = 5000; testNow <= 30000; testNow += 5000) terminal_mqtt::update();
  assert(broker.connectCalls == 0);
  assert(!terminal_mqtt::connected());

  // Hora sincronizada, certificado recusado: a conexao falha, o transporte e
  // liberado e o motivo e consultado (sem expor credenciais nem payload).
  testClock = 1792438213ULL;
  testNow = 35000;
  broker.connectResult = false;
  terminal_mqtt::update();
  assert(broker.connectCalls == 1);
  assert(!terminal_mqtt::connected());
  assert(tls.stopCalls == 1);
  assert(tls.lastErrorCalls == 1);
  assert(broker.subscriptions == 0);  // Sem TLS valido nao existe inscricao: nada abre.

  // A retentativa respeita o intervalo existente.
  testNow = 39999;
  terminal_mqtt::update();
  assert(broker.connectCalls == 1);

  // Certificado aceito: conecta e se inscreve; a validacao segue ligada.
  testNow = 40000;
  broker.connectResult = true;
  terminal_mqtt::update();
  assert(broker.connectCalls == 2);
  assert(terminal_mqtt::connected());
  assert(broker.subscriptions == 2);
  assert(tls.insecureCalls == 0);

  // Relogio que volta a ficar nao confiavel (ex.: reinicio parcial) bloqueia nova conexao.
  broker.online = false;
  testClock = 0;
  testNow = 45000;
  terminal_mqtt::update();
  assert(broker.connectCalls == 2);

  puts("mqtt tls: CA, hora confiavel, certificado recusado e reconexao OK");
}
