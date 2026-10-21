#pragma once

// Copie config.example.h para config.h antes de compilar (README do firmware).
#include <config.h>

namespace terminal_settings {
constexpr const char* id = TERMINAL_ID;
constexpr const char* commandsTopic = MQTT_TOPIC_COMMANDS;
constexpr const char* acksTopic = MQTT_TOPIC_ACKS;
}
