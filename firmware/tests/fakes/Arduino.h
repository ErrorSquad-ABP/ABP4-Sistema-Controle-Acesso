#pragma once

#include <stdint.h>

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
