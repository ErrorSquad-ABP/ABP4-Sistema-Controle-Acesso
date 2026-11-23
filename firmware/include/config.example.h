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

// DT-06: 0 = texto claro (Mosquitto dev/Wokwi); 1 = TLS com validacao de cadeia,
// validade e hostname contra o CA de include/mqtt_ca.h. Producao exige 1, com o
// host do broker de producao (EMQX Cloud Serverless), porta 8883 e usuario/senha (so no config.h local).
// O handshake bloqueia o loop ate este teto (core 2.x: segundos).
#ifndef MQTT_USE_TLS
#define MQTT_USE_TLS 0
#endif
#define MQTT_HANDSHAKE_TIMEOUT_SECONDS 5

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

#ifndef TERMINAL_LEGACY_TFT
#define TERMINAL_LEGACY_TFT 0
#endif

// Perfil fisico de 07/11/2026. Nunca alimentar RC522 com 5 V.
#define NFC_ENABLED (!TERMINAL_LEGACY_TFT)
#define NFC_SCK_PIN 18
#define NFC_MISO_PIN 19
#define NFC_MOSI_PIN 23
#define NFC_SS_PIN 32
#define NFC_RST_PIN 33
#define NFC_POLL_MS 100U
#define NFC_REMOVAL_MS 500U

#if TERMINAL_LEGACY_TFT
// Perfil legado, exclusivo do Wokwi: RC522 desabilitado por conflito de pinos.
#define DOOR_ENABLED 1
#define FEEDBACK_BUZZER_ENABLED 1
#define DOOR_SERVO_PIN 14
#define FEEDBACK_RED_LED_PIN 5
#define FEEDBACK_GREEN_LED_PIN 18
#define FEEDBACK_BUZZER_PIN 19
#define FEEDBACK_LED_ACTIVE_LOW 0
#else
// Habilitar servo SOMENTE apos confirmar modelo, calibracao e alimentacao.
#define DOOR_ENABLED 0
#define DOOR_SERVO_PIN 26
#define FEEDBACK_RED_LED_PIN 25
#define FEEDBACK_GREEN_LED_PIN 27
#define FEEDBACK_BUZZER_PIN 14
#define FEEDBACK_LED_ACTIVE_LOW 1
// Habilitar apenas para piezo passivo compativel com GPIO ou driver adequado.
#define FEEDBACK_BUZZER_ENABLED 0
#endif

#define OLED_SDA_PIN 21
#define OLED_SCL_PIN 22
#define OLED_ADDRESS 0x3C
// LCD opcional: 3,3 V compativel ou conversor de nivel, nunca pull-ups a 5 V.
#define LCD_ENABLED 0
#define LCD_SDA_PIN 16
#define LCD_SCL_PIN 17
#define LCD_ADDRESS 0x27

// Atuacao herdada do prototipo (teste-servo). Servo de rotacao continua: os
// valores escolhem sentido e velocidade, nao uma posicao angular.
#define DOOR_SERVO_OPEN 180
#define DOOR_SERVO_STOP 90
#define DOOR_SERVO_CLOSE 0
// Faixa do pulso (us) mapeada em 0..180. Com 1000..2000, o STOP (90) vira 1500 us,
// o neutro do servo continuo. Com a faixa antiga (500..2400) o STOP saia em 1450 us
// e o servo girava devagar sozinho. Se ainda arrastar, ajuste o trimpot do servo.
#define DOOR_SERVO_MIN_US 1000
#define DOOR_SERVO_MAX_US 2000
#define DOOR_MOVE_MS 1800U
#define DOOR_HOLD_OPEN_MS 3000U

// tone() usa LEDC; o canal 0 e do servo (ESP32Servo). Reserve outro canal.
#define FEEDBACK_TONE_CHANNEL 4

// TFT ILI9341 240x320 por SPI por software: preserva os pinos do prototipo.
#define TFT_CS_PIN 27
#define TFT_DC_PIN 26
#define TFT_RST_PIN 25
#define TFT_MOSI_PIN 32
#define TFT_SCK_PIN 33

// Display: 0 = status OLED/LCD no perfil fisico, ou TFT no perfil legado.
// 1 = QR compacto no OLED (US-29), em vez do status OLED/LCD.
// O guard permite habilitar a variante por -DTERMINAL_DISPLAY_OLED=1 no build.
#ifndef TERMINAL_DISPLAY_OLED
#define TERMINAL_DISPLAY_OLED 0
#endif
#define OLED_I2C_ADDRESS OLED_ADDRESS
