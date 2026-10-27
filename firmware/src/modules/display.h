#pragma once

#include <stdint.h>

#include "door_machine.h"
#include "qr_token.h"

namespace terminal_display {
void begin();
void update();
void showReading();
void showGranted();
void showDenied();
void showDoor(door_machine::State state);

/** Desenha o QR rotativo e a contagem regressiva; sem token valido, apaga a area. */
void showQr(const qr_token::State& state, uint64_t nowEpoch, bool clockValid);
}  // namespace terminal_display
