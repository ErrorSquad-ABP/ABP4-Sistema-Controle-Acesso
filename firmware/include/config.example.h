#pragma once

// Desenvolvimento/Wokwi apenas. Copie para config.h e nunca versione segredos.
#define TERMINAL_ID "terminal-dev-01"
#define WIFI_SSID "Wokwi-GUEST"
#define WIFI_PASSWORD ""
#define WIFI_RETRY_MS 5000U

// No hardware real, use o IP local do computador que executa o compose.
// host.wokwi.internal requer o gateway integrado do Wokwi para VS Code.
#define MQTT_HOST "host.wokwi.internal"
#define MQTT_PORT 1884
#define MQTT_USERNAME ""
#define MQTT_PASSWORD ""
#define MQTT_RETRY_MS 5000U
#define MQTT_SOCKET_TIMEOUT_SECONDS 1
#define MQTT_TCP_TIMEOUT_SECONDS 1

// Matriz de transporte da arquitetura; payloads v1 pertencem a US-04.
#define MQTT_TOPIC_PREFIX "terminals/" TERMINAL_ID
#define MQTT_TOPIC_QR MQTT_TOPIC_PREFIX "/qr"
#define MQTT_TOPIC_ACCESS_EVENTS MQTT_TOPIC_PREFIX "/access-events"
#define MQTT_TOPIC_STATUS MQTT_TOPIC_PREFIX "/status"
#define MQTT_TOPIC_COMMANDS MQTT_TOPIC_PREFIX "/commands"
#define MQTT_TOPIC_ACKS MQTT_TOPIC_PREFIX "/acks"

// O prazo (`expiresAt`) do comando so pode ser conferido com relogio UTC real.
#define NTP_SERVER_PRIMARY "pool.ntp.org"
#define NTP_SERVER_SECONDARY "time.nist.gov"

// Atuacao herdada do prototipo (teste-servo). Servo de rotacao continua: os
// valores escolhem sentido e velocidade, nao uma posicao angular.
#define DOOR_SERVO_PIN 14
#define DOOR_SERVO_OPEN 180
#define DOOR_SERVO_STOP 90
#define DOOR_SERVO_CLOSE 0
#define DOOR_MOVE_MS 1800U
#define DOOR_HOLD_OPEN_MS 3000U

// LED RGB de anodo comum: nivel LOW acende.
#define FEEDBACK_RED_LED_PIN 5
#define FEEDBACK_GREEN_LED_PIN 18
#define FEEDBACK_BUZZER_PIN 19
// Wokwi/teste: anodo no GPIO (HIGH acende). No hardware legado common-anode, use 1.
#define FEEDBACK_LED_ACTIVE_LOW 0
// tone() usa LEDC; o canal 0 e do servo (ESP32Servo). Reserve outro canal.
#define FEEDBACK_TONE_CHANNEL 4

// LCD 1602 com expansor I2C (PCF8574 no endereco 0x27).
#define DISPLAY_SDA_PIN 21
#define DISPLAY_SCL_PIN 22
#define DISPLAY_I2C_ADDRESS 0x27
#define DISPLAY_COLUMNS 16
#define DISPLAY_ROWS 2
