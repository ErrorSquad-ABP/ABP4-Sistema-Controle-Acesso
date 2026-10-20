#pragma once

#include <stdint.h>

constexpr int WIFI_STA = 1;
constexpr int WL_CONNECTED = 3;
constexpr int WL_DISCONNECTED = 6;

struct TestWiFi {
  int currentStatus = WL_DISCONNECTED;
  int beginCalls = 0;
  void mode(int) {}
  void persistent(bool) {}
  void setAutoReconnect(bool) {}
  int status() { return currentStatus; }
  void disconnect() { currentStatus = WL_DISCONNECTED; }
  void begin(const char*, const char*) { ++beginCalls; }
};
extern TestWiFi WiFi;
extern uint32_t tcpTimeoutSeconds;

struct WiFiClient {
  int setTimeout(uint32_t seconds) { tcpTimeoutSeconds = seconds; return 0; }
  void stop() {}
};
