#pragma once

#include <stdint.h>

#include "command.h"
#include "qr_token.h"

namespace terminal_mqtt {

using Actuator = terminal_command::Handler::Actuator;
using Clock = uint64_t (*)();

void begin();
void update(bool allowReconnect = true);
bool connected();
// Confirma PUBACK (QoS 1); nunca decide acesso nem publica sem UTC confiavel.
bool publishNfc(const char* uid);

/** Ultimo QR valido recebido do backend (o display decide se ainda esta visivel). */
qr_token::State qr();

// Injecao feita pelo main: o modulo nao conhece servo, LED nem relogio.
void setActuator(Actuator actuator);
void setClock(Clock clock);

}  // namespace terminal_mqtt
