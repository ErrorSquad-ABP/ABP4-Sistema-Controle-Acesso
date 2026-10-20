#pragma once

#include "WiFi.h"

struct TestBroker {
  bool connectResult = false;
  bool subscribeResult = true;
  bool online = false;
  int connectCalls = 0;
  int loopCalls = 0;
  int subscriptions = 0;
  const char* clientId = "";
  const char* topic = "";
  unsigned int qos = 0;
};
extern TestBroker broker;

class PubSubClient {
 public:
  explicit PubSubClient(WiFiClient&) {}
  void setServer(const char*, uint16_t) {}
  void setSocketTimeout(uint16_t) {}
  void setCallback(void (*)(char*, uint8_t*, unsigned int)) {}
  bool connected() { return broker.online; }
  bool connect(const char* clientId) {
    broker.clientId = clientId;
    ++broker.connectCalls;
    broker.online = broker.connectResult;
    return broker.online;
  }
  bool connect(const char* clientId, const char*, const char*) {
    return connect(clientId);
  }
  bool subscribe(const char* topic, uint8_t qos) {
    broker.topic = topic;
    broker.qos = qos;
    ++broker.subscriptions;
    return broker.subscribeResult;
  }
  void disconnect() { broker.online = false; }
  bool loop() { ++broker.loopCalls; return broker.online; }
  int state() { return -2; }
};
