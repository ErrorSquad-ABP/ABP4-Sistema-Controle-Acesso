#pragma once

#include <string.h>

#include "WiFi.h"

class MQTTClient;
struct TestBroker {
  bool connectResult = false;
  bool subscribeResult = true;
  bool publishResult = true;
  bool online = false;
  int connectCalls = 0;
  int loopCalls = 0;
  int subscriptions = 0;
  const char* subscribedTopics[8] = {};
  int publishCalls = 0;
  const char* clientId = "";
  const char* topic = "";
  const char* publishedTopic = "";
  char publishedPayload[512] = {0};
  bool publishedRetained = true;
  int publishedQos = -1;
  unsigned int qos = 0;
  unsigned int bufferSize = 256;
  void (*callback)(MQTTClient*, char*, char*, int) = nullptr;
};
extern TestBroker broker;

class MQTTClient {
 public:
  explicit MQTTClient(int size) : size_(size) {}
  void begin(const char*, int, WiFiClient&) { broker.bufferSize = size_; }
  void setTimeout(int) {}
  void onMessageAdvanced(void (*callback)(MQTTClient*, char*, char*, int)) {
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
    if (broker.subscriptions < 8) broker.subscribedTopics[broker.subscriptions] = topic;
    broker.qos = qos;
    ++broker.subscriptions;
    return broker.subscribeResult;
  }
  bool publish(const char* topic, const char* payload, int length, bool retained, int qos) {
    broker.publishedTopic = topic;
    const unsigned int copied = static_cast<unsigned int>(length) < sizeof broker.publishedPayload - 1
        ? static_cast<unsigned int>(length)
        : static_cast<unsigned int>(sizeof broker.publishedPayload - 1);
    memcpy(broker.publishedPayload, payload, copied);
    broker.publishedPayload[copied] = '\0';
    broker.publishedRetained = retained;
    broker.publishedQos = qos;
    ++broker.publishCalls;
    return broker.publishResult;
  }
  void disconnect() { broker.online = false; }
  bool loop() { ++broker.loopCalls; return broker.online; }
  int lastError() { return -2; }
 private:
  unsigned int size_;
};
