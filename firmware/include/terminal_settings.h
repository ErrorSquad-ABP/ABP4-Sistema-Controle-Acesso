#pragma once

// Copie config.example.h para config.h antes de compilar (README do firmware).
#include <config.h>

// Padroes para config.h antigos, que nao conhecem estas chaves.
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
#define OLED_I2C_ADDRESS 0x3C
#endif

namespace terminal_settings {
constexpr const char* id = TERMINAL_ID;
constexpr const char* qrTopic = MQTT_TOPIC_QR;
constexpr const char* commandsTopic = MQTT_TOPIC_COMMANDS;
constexpr const char* acksTopic = MQTT_TOPIC_ACKS;
}  // namespace terminal_settings
