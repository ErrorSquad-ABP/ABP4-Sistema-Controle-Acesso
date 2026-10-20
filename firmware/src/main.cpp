#include <Arduino.h>

#include "modules/display.h"
#include "modules/door.h"
#include "modules/feedback.h"
#include "modules/gps.h"
#include "modules/mqtt.h"
#include "modules/nfc.h"

void setup() {
  Serial.begin(115200);
  Serial.println("[terminal] iniciando esqueleto US-07");
  terminal_display::begin();
  terminal_nfc::begin();
  terminal_gps::begin();
  terminal_feedback::begin();
  terminal_door::begin();
  terminal_mqtt::begin();
}

void loop() {
  terminal_mqtt::update();
  terminal_display::update();
  terminal_nfc::update();
  terminal_gps::update();
  terminal_feedback::update();
  terminal_door::update();
  delay(10);  // Cede tempo ao scheduler do ESP32, sem esperar conexao de rede.
}
