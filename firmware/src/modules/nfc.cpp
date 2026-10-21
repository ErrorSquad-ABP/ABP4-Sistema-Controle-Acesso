#include "nfc.h"

#include <Arduino.h>

namespace terminal_nfc {
void begin() { Serial.println("[nfc] esqueleto; leitura desabilitada"); }
void update() {}  // Proximo card de NFC: leitura e publicacao sem decisao local.
}
