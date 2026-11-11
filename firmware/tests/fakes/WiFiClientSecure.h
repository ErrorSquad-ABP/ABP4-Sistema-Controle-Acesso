#pragma once

#include <stddef.h>
#include <string.h>

#include "WiFi.h"

// Estado observavel do transporte TLS; cada teste define `tls` (como `broker`).
struct TestTls {
  const char* caCert = nullptr;
  int caCalls = 0;
  int insecureCalls = 0;
  int stopCalls = 0;
  int lastErrorCalls = 0;
  int lastErrorCode = -0x2700;  // MBEDTLS_ERR_X509_CERT_VERIFY_FAILED
  unsigned long handshakeTimeoutSeconds = 0;
};
extern TestTls tls;

struct WiFiClientSecure : WiFiClient {
  void setCACert(const char* rootCA) {
    tls.caCert = rootCA;
    ++tls.caCalls;
  }
  void setInsecure() { ++tls.insecureCalls; }
  void setHandshakeTimeout(unsigned long seconds) { tls.handshakeTimeoutSeconds = seconds; }
  int lastError(char* buffer, size_t size) {
    ++tls.lastErrorCalls;
    strncpy(buffer, "X509 - Certificate verification failed", size - 1);
    buffer[size - 1] = '\0';
    return tls.lastErrorCode;
  }
  void stop() {
    ++tls.stopCalls;
    WiFiClient::stop();
  }
};
