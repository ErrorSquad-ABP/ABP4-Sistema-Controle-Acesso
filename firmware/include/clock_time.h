#pragma once

#include <stdint.h>

// Relogio UTC real: o prazo (`expiresAt`) de um comando so pode ser conferido
// com hora de parede, nao com millis().
namespace clock_time {

void begin();

// Retorna 0 enquanto o SNTP nao sincronizou; nunca devolve hora inventada.
uint64_t nowEpoch();

}  // namespace clock_time
