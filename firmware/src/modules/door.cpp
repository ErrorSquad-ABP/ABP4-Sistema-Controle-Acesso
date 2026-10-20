#include "door.h"

#include <Arduino.h>

namespace terminal_door {
void begin() { Serial.println("[door] esqueleto; atuacao desabilitada"); }
void update() {}  // US-08: servo; so atuar apos comando validado do backend.
}
