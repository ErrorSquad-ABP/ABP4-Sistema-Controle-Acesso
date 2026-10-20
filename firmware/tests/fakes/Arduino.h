#pragma once

#include <stdint.h>

extern uint32_t testNow;
inline uint32_t millis() { return testNow; }

struct TestSerial {
  void println(const char*) {}
  template <typename... Args>
  void printf(const char*, Args...) {}
};
extern TestSerial Serial;
