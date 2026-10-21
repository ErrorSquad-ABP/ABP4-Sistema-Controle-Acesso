#pragma once

#include <string.h>

#include "WiFi.h"

struct TestBroker {
  bool connectResult = false;
  bool subscribeResult = true;
  bool publishResult = true;
  bool online = false;
  int connectCalls = 0;
  int loopCalls = 0;
  int subscriptions = 0;
  int publishCalls = 0;
  const char* clientId = "";
  const char* topic = "";
  const char* publishedTopic = "";
  char publishedPayload[512] = {0};
  bool publishedRetained = true;
  unsigned int qos = 0;
  unsigned int bufferSize = 256;
  void (*callback)(char*, uint8_t*, unsigned int) = nullptr;
};
extern TestBroker broker;

class PubSubClient {
 public:
  explicit PubSubClient(WiFiClient&) {}
  void setServer(const char*, uint16_t) {}
  void setSocketTimeout(uint16_t) {}
  void setBufferSize(unsigned int size) { broker.bufferSize = size; }
  void setCallback(void (*callback)(char*, uint8_t*, unsigned int)) {
    broker.callback = callback;
  }
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
  bool publish(const char* topic, const uint8_t* payload, unsigned int length, bool retained) {
    broker.publishedTopic = topic;
    const unsigned int copied = length < sizeof broker.publishedPayload - 1
        ? length
        : static_cast<unsigned int>(sizeof broker.publishedPayload - 1);
    memcpy(broker.publishedPayload, payload, copied);
    broker.publishedPayload[copied] = '\0';
    broker.publishedRetained = retained;
    ++broker.publishCalls;
    return broker.publishResult;
  }
  void disconnect() { broker.online = false; }
  bool loop() { ++broker.loopCalls; return broker.online; }
  int state() { return -2; }
};
