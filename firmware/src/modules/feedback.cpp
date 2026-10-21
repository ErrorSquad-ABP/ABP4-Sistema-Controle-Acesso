#include "feedback.h"

#include <Arduino.h>

namespace terminal_feedback {
void begin() { Serial.println("[feedback] esqueleto; LED e buzzer desabilitados"); }
void update() {}  // US-08: feedback fisico sem bloquear o loop.
}
