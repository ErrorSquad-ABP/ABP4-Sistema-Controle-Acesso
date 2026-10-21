#pragma once

#include <stdint.h>

#include "command.h"

namespace terminal_mqtt {

using Actuator = terminal_command::Handler::Actuator;
using Clock = uint64_t (*)();

void begin();
void update();
bool connected();

// Injecao feita pelo main: o modulo nao conhece servo, LED nem relogio.
void setActuator(Actuator actuator);
void setClock(Clock clock);

}  // namespace terminal_mqtt
