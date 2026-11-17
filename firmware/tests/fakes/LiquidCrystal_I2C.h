#pragma once

#include <stdint.h>
#include <string.h>
#include "Wire.h"

struct TestLcd {
  bool initialized = false;
  bool backlight = false;
  uint8_t row = 0;
  uint8_t column = 0;
  char lines[2][17] = {};
};
extern TestLcd testLcd;

class LiquidCrystal_I2C {
 public:
  LiquidCrystal_I2C(uint8_t, uint8_t, uint8_t) {}
  void init() { Wire.begin(); testLcd.initialized = true; }
  void backlight() { testLcd.backlight = true; }
  void clear() { send(); memset(testLcd.lines, 0, sizeof testLcd.lines); }
  void setCursor(uint8_t column, uint8_t row) { send(); testLcd.row = row; testLcd.column = column; }
  void print(const char* text) {
    while (*text) print(*text++);
  }
  void print(char value) {
    if (send() && testLcd.column < 16) testLcd.lines[testLcd.row][testLcd.column++] = value;
  }
 private:
  bool send() {
    bool sent = true;
    for (int i = 0; i < 6; ++i) {
      Wire.beginTransmission(0x27);
      if (Wire.endTransmission() != 0) sent = false;
    }
    return sent;
  }
};
