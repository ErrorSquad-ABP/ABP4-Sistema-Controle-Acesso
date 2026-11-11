#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "Arduino.h"
#include "ESP32Servo.h"
#include "MQTTClient.h"
#include "WiFiClientSecure.h"
#include "modules/display.h"
#include "modules/door.h"
#include "modules/mqtt.h"
#include "modules/nfc.h"

uint32_t testNow = 0;
uint32_t tcpTimeoutSeconds = 0;
TestSerial Serial;
TestWiFi WiFi;
TestBroker broker;
TestTls tls;
TestEsp ESP;
TestServo testServo;
void pinMode(uint8_t, uint8_t) {}
void digitalWrite(uint8_t, uint8_t) {}

namespace clock_time {
void begin() {}
uint64_t nowEpoch() { return 1792438213ULL; }
}
namespace terminal_display {
void begin() {}
void update() {}
void showGranted() {}
void showDenied() {}
void showReading() {}
void showDoor(door_machine::State) {}
void showQr(const qr_token::State&, uint64_t, bool) {}
}
namespace terminal_feedback {
void begin() {}
void update() {}
void playGranted() {}
void playDenied() {}
}
namespace terminal_nfc {
void setPublisher(Publisher) {}
void begin() {}
void update() {}
}
namespace terminal_gps {
void begin() {}
void update() {}
}

void setup();
void loop();

int main(int argc, char** argv) {
  assert(argc == 2);
  setup();
  WiFi.currentStatus = WL_CONNECTED;
  broker.connectResult = true;
  testNow = 5000;
  loop();
  assert(terminal_mqtt::connected());

  testNow = 10000;
  assert(terminal_door::requestOpen());
  const int loops = broker.loopCalls;
  loop();
  assert(broker.loopCalls > loops);
  assert(testServo.value == 180);
  assert(testServo.attached);

  const bool dropOpening = strcmp(argv[1], "opening") == 0;
  const bool dropOpen = strcmp(argv[1], "open") == 0;
  const bool dropClosing = strcmp(argv[1], "closing") == 0;
  assert(dropOpening || dropOpen || dropClosing);
  broker.connectDelayMs = 5000;
  const int connects = broker.connectCalls;

  if (dropOpening) broker.online = false;
  testNow = 11000;
  loop();
  assert(broker.connectCalls == connects);
  assert(terminal_door::state() == door_machine::State::opening);
  assert(testServo.value == 180);

  testNow = 11800;
  loop();
  assert(testServo.value == 90 && testServo.writtenAt == 11800);
  assert(terminal_door::state() == door_machine::State::open);

  if (dropOpen) broker.online = false;
  testNow = 13000;
  loop();
  assert(broker.connectCalls == connects);
  assert(terminal_door::state() == door_machine::State::open);

  testNow = 14800;
  loop();
  assert(testServo.value == 0 && testServo.writtenAt == 14800);
  assert(terminal_door::state() == door_machine::State::closing);

  if (dropClosing) broker.online = false;
  testNow = 15000;
  loop();
  assert(broker.connectCalls == connects);
  assert(terminal_door::state() == door_machine::State::closing);
  assert(testServo.value == 0);

  testNow = 16600;
  loop();
  assert(terminal_door::state() == door_machine::State::idle);
  assert(testServo.value == 90 && testServo.writtenAt == 16600);
  assert(!testServo.attached);  // parado: sem pulso, o servo continuo nao arrasta
  assert(broker.connectCalls == connects + 1);
  assert(terminal_mqtt::connected());
  printf("mqtt door timing: queda em %s, parada antes de reconectar OK\n", argv[1]);
}
