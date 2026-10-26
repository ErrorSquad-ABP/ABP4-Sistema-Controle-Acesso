#include <Arduino.h>

#include "clock_time.h"
#include "modules/display.h"
#include "modules/door.h"
#include "modules/feedback.h"
#include "modules/gps.h"
#include "modules/mqtt.h"
#include "modules/nfc.h"

namespace {

// O backend decide; aqui so se executa a acao ja validada e se devolve o ACK.
bool handleCommand(terminal_command::Action action) {
  if (action == terminal_command::Action::open) {
    if (!terminal_door::requestOpen()) return false;
    terminal_feedback::playGranted();
    terminal_display::showGranted();
    return true;
  }
  terminal_feedback::playDenied();
  terminal_display::showDenied();
  return true;
}

}  // namespace

void setup() {
  Serial.begin(115200);
  Serial.println("[terminal] iniciando atuacao (US-08)");
  clock_time::begin();
  terminal_display::begin();
  terminal_nfc::begin();
  terminal_gps::begin();
  terminal_feedback::begin();
  terminal_door::begin();
  terminal_mqtt::setActuator(handleCommand);
  terminal_mqtt::setClock(clock_time::nowEpoch);
  terminal_mqtt::begin();
}

void loop() {
  terminal_mqtt::update();
  terminal_door::update();
  terminal_feedback::update();
  const uint64_t now = clock_time::nowEpoch();
  terminal_display::showQr(terminal_mqtt::qr(), now, now != 0);
  terminal_display::showDoor(terminal_door::state());
  terminal_display::update();
  terminal_nfc::update();
  terminal_gps::update();
  delay(10);  // Cede tempo ao scheduler do ESP32, sem esperar conexao de rede.
}
