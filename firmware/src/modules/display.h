#pragma once

#include "door_machine.h"

namespace terminal_display {
void begin();
void update();
void showReading();
void showGranted();
void showDenied();
void showDoor(door_machine::State state);
}  // namespace terminal_display
