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
