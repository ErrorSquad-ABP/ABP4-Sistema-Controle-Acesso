#pragma once

#include "Arduino.h"

struct TestServo {
  int value = 90;
  uint32_t writtenAt = 0;
  bool attached = false;
};
extern TestServo testServo;

class Servo {
 public:
  void setPeriodHertz(int) {}
  void attach(int, int, int) { testServo.attached = true; }
  void detach() { testServo.attached = false; }
  bool attached() const { return testServo.attached; }
  void write(int value) {
    testServo.value = value;
    testServo.writtenAt = millis();
  }
};
