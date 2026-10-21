#include "display.h"

#include <Arduino.h>

namespace terminal_display {
void begin() { Serial.println("[display] esqueleto; renderizacao QR pendente"); }
void update() {}  // US-08: adaptador de display; US-04: mensagem QR.
}
