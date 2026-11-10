#pragma once

// Copie config.example.h para config.h antes de compilar (README do firmware).
#include <config.h>

#if !defined(TERMINAL_LEGACY_TFT) || !defined(NFC_ENABLED) || !defined(DOOR_ENABLED) || !defined(FEEDBACK_BUZZER_ENABLED)
#error "config.h antigo: migre os perfis/pinos a partir de config.example.h (US-23), preservando seus segredos."
#endif

namespace terminal_settings {
constexpr const char* id = TERMINAL_ID;
constexpr const char* qrTopic = MQTT_TOPIC_QR;
constexpr const char* commandsTopic = MQTT_TOPIC_COMMANDS;
constexpr const char* acksTopic = MQTT_TOPIC_ACKS;
constexpr const char* accessEventsTopic = MQTT_TOPIC_ACCESS_EVENTS;
}  // namespace terminal_settings
