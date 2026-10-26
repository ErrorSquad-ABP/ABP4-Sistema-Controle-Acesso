#pragma once

#include <stdint.h>

// Estado do QR rotativo recebido do backend, sem dependencia de Arduino: a
// validade e testada no host e o display so desenha o que estiver visivel.
namespace qr_token {

struct State {
  char token[65] = {0};
  uint64_t expiresAt = 0;
  bool hasToken = false;
};

inline bool visible(const State& state, uint64_t nowEpoch, bool clockValid) {
  if (!state.hasToken || !clockValid) return false;
  if (state.token[0] == '\0') return false;
  return nowEpoch < state.expiresAt;
}

inline uint32_t secondsLeft(const State& state, uint64_t nowEpoch, bool clockValid) {
  if (!visible(state, nowEpoch, clockValid)) return 0;
  return static_cast<uint32_t>(state.expiresAt - nowEpoch);
}

}  // namespace qr_token
