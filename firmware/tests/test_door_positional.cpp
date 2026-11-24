#include <assert.h>
#include <stdio.h>

#include "Arduino.h"
#include "ESP32Servo.h"
#include "modules/door.h"

uint32_t testNow = 0;
TestSerial Serial;
TestServo testServo;
void pinMode(uint8_t, uint8_t) {}
void digitalWrite(uint8_t, uint8_t) {}

int main() {
  terminal_door::begin();
  assert(!testServo.attached);
  testNow = 100;
  assert(terminal_door::requestOpen());
  assert(testServo.attached && testServo.value == 135);
  assert(!terminal_door::requestOpen());
  testNow = 1900;
  terminal_door::update();
  assert(terminal_door::state() == door_machine::State::open);
  assert(testServo.attached && testServo.value == 135);
  assert(testServo.writtenAt == 100);
  testNow = 4900;
  terminal_door::update();
  assert(testServo.attached && testServo.value == 45);
  testNow = 6700;
  terminal_door::update();
  assert(terminal_door::state() == door_machine::State::idle);
  assert(!testServo.attached && testServo.value == 45);
  assert(testServo.writtenAt == 4900);
  testNow = 7000;
  assert(terminal_door::requestOpen());
  assert(testServo.attached && testServo.value == 135);
  puts("door positional: sem movimento no boot, mantem abertura e termina fechado sem pulso neutro OK");
}
