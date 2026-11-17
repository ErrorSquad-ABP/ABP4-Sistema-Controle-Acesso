#pragma once

#include "Wire.h"
#include <stdint.h>
#include <string.h>

constexpr uint8_t SSD1306_WHITE = 1;
constexpr uint8_t SSD1306_BLACK = 0;
constexpr uint8_t SSD1306_SWITCHCAPVCC = 2;
constexpr uint8_t SSD1306_SETCONTRAST = 0x81;
struct TestOled {
  uint8_t pixels[128 * 64] = {};
  int bus = -1;
  int frames = 0;
  char text[64] = {};
};
extern TestOled testOled;

class Adafruit_SSD1306 {
 public:
  Adafruit_SSD1306(int, int, TwoWire* wire, int) : wire_(wire) {}
  bool begin(uint8_t, uint8_t address, bool = true, bool periphBegin = true) {
    testOled.bus = wire_->bus();
    if (periphBegin) wire_->begin();
    wire_->beginTransmission(address);
    return wire_->endTransmission() == 0;
  }
  void clearDisplay() { fillScreen(0); testOled.text[0] = '\0'; }
  void fillScreen(uint8_t color) { memset(testOled.pixels, color, sizeof testOled.pixels); }
  void fillRect(int x, int y, int width, int height, uint8_t color) {
    for (int row = y; row < y + height; ++row)
      for (int column = x; column < x + width; ++column)
        if (row >= 0 && row < 64 && column >= 0 && column < 128)
          testOled.pixels[row * 128 + column] = color;
  }
  void setTextColor(uint8_t) {}
  void setTextSize(uint8_t) {}
  void setTextWrap(bool) {}
  void setCursor(int, int) {}
  void print(const char* text) {
    const size_t used = strlen(testOled.text);
    strncat(testOled.text, text, sizeof testOled.text - used - 1);
  }
  void display() { ++testOled.frames; }
  void invertDisplay(bool) {}
  void ssd1306_command(uint8_t) {}
 private:
  TwoWire* wire_;
};
