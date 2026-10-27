#pragma once

#include <stdint.h>

// Hora de parede confiavel: o SNTP so vale a partir de 2025-01-01. Antes disso
// `time()` pode devolver um valor positivo (1970) sem ter sincronizado.
namespace clock_policy {

constexpr uint64_t kValidFromEpoch = 1735689600ULL;  // 2025-01-01T00:00:00Z

inline bool reliable(uint64_t epoch) { return epoch >= kValidFromEpoch; }

}  // namespace clock_policy
