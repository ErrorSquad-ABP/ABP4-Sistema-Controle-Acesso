#pragma once

#include <stdint.h>

constexpr uint8_t LOW = 0;
constexpr uint8_t HIGH = 1;
constexpr uint8_t OUTPUT = 1;
void pinMode(uint8_t pin, uint8_t mode);
void digitalWrite(uint8_t pin, uint8_t value);
void setToneChannel(uint8_t channel);
void tone(uint8_t pin, unsigned int hz);
void noTone(uint8_t pin);

extern uint32_t testNow;
inline uint32_t millis() { return testNow; }

inline uint32_t esp_random() {
  static uint32_t counter = 0x12345678;
  counter = counter * 1664525u + 1013904223u;
  return counter;
}

struct TestSerial {
  void println(const char*) {}
  template <typename... Args>
  void printf(const char*, Args...) {}
};
extern TestSerial Serial;
