#pragma once

#include "Arduino.h"

struct TestServo {
  int value = 90;
  uint32_t writtenAt = 0;
};
extern TestServo testServo;

class Servo {
 public:
  void setPeriodHertz(int) {}
  void attach(int, int, int) {}
  void write(int value) {
    testServo.value = value;
    testServo.writtenAt = millis();
  }
};
