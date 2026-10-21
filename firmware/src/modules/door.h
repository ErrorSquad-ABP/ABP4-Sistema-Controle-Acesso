#pragma once

#include "door_machine.h"

namespace terminal_door {
void begin();
void update();
bool requestOpen();
door_machine::State state();
}  // namespace terminal_door
