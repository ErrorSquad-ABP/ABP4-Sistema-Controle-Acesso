#pragma once

#include <stdint.h>

extern uint32_t testNow;
inline uint32_t millis() { return testNow; }
inline void delay(uint32_t ms) { testNow += ms; }

// GPIO: door.cpp deixa o pino do servo em LOW quando a cancela esta parada.
constexpr uint8_t OUTPUT = 1;
constexpr uint8_t LOW = 0;
constexpr uint8_t HIGH = 1;
inline void pinMode(uint8_t, uint8_t) {}
inline void digitalWrite(uint8_t, uint8_t) {}

inline uint32_t esp_random() {
  static uint32_t counter = 0x12345678;
  counter = counter * 1664525u + 1013904223u;
  return counter;
}

// Usado so pelo log de heap do TLS; o teste que o exercita define `ESP`.
struct TestEsp {
  uint32_t getFreeHeap() { return 200000; }
};
extern TestEsp ESP;

struct TestSerial {
  void begin(unsigned long) {}
  void println(const char*) {}
  template <typename... Args>
  void printf(const char*, Args...) {}
};
extern TestSerial Serial;
