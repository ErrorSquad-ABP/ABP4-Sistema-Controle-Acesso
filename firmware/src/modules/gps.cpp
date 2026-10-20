#include "gps.h"

#include <Arduino.h>

namespace terminal_gps {
void begin() { Serial.println("[gps] esqueleto; sem posicao disponivel"); }
void update() {}  // Nao simular coordenadas validas na ausencia de um fix.
}
