#pragma once

#include <stdint.h>
#include "Arduino.h"

struct TestWire {
  int sda = -1;
  int scl = -1;
  uint8_t address = 0;
  bool present = true;
  uint16_t timeout = 50;
  int attempts = 0;
  int failAt = 0;
};
extern TestWire testWires[2];

class TwoWire {
 public:
  explicit TwoWire(int bus) : bus_(bus) {}
  void begin() {}
  void begin(int sda, int scl) { testWires[bus_].sda = sda; testWires[bus_].scl = scl; }
  void setClock(uint32_t) {}
  void setTimeOut(uint16_t timeout) { testWires[bus_].timeout = timeout; }
  void beginTransmission(uint8_t address) { testWires[bus_].address = address; }
  uint8_t endTransmission() {
    TestWire& wire = testWires[bus_];
    ++wire.attempts;
    if (!wire.present || (wire.failAt && wire.attempts >= wire.failAt)) {
      testNow += wire.timeout;
      return 2;
    }
    return 0;
  }
  int bus() const { return bus_; }
 private:
  int bus_;
};
extern TwoWire Wire;
