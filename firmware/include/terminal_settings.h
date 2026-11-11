#pragma once

// Copie config.example.h para config.h antes de compilar (README do firmware).
#include <config.h>

#if !defined(TERMINAL_LEGACY_TFT) || !defined(NFC_ENABLED) || !defined(DOOR_ENABLED) || !defined(FEEDBACK_BUZZER_ENABLED)
#error "config.h antigo: migre os perfis/pinos a partir de config.example.h (US-23), preservando seus segredos."
#endif

// Configuracoes locais da US-23 podem ainda nao conhecer as opcoes novas da main.
#ifndef MQTT_USE_TLS
#define MQTT_USE_TLS 0
#endif
#ifndef MQTT_HANDSHAKE_TIMEOUT_SECONDS
#define MQTT_HANDSHAKE_TIMEOUT_SECONDS 5
#endif
#ifndef DOOR_SERVO_MIN_US
#define DOOR_SERVO_MIN_US 1000
#endif
#ifndef DOOR_SERVO_MAX_US
#define DOOR_SERVO_MAX_US 2000
#endif
#ifndef TERMINAL_DISPLAY_OLED
#define TERMINAL_DISPLAY_OLED 0
#endif
#ifndef OLED_SDA_PIN
#define OLED_SDA_PIN 21
#endif
#ifndef OLED_SCL_PIN
#define OLED_SCL_PIN 22
#endif
#ifndef OLED_I2C_ADDRESS
#ifdef OLED_ADDRESS
#define OLED_I2C_ADDRESS OLED_ADDRESS
#else
#define OLED_I2C_ADDRESS 0x3C
#endif
#endif

namespace terminal_settings {
constexpr const char* id = TERMINAL_ID;
constexpr const char* qrTopic = MQTT_TOPIC_QR;
constexpr const char* commandsTopic = MQTT_TOPIC_COMMANDS;
constexpr const char* acksTopic = MQTT_TOPIC_ACKS;
constexpr const char* accessEventsTopic = MQTT_TOPIC_ACCESS_EVENTS;
}  // namespace terminal_settings
