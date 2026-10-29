#pragma once

#include <stddef.h>
#include <stdint.h>

// Estado do QR rotativo recebido do backend, sem dependencia de Arduino: a
// validade e testada no host e o display so desenha o que estiver visivel.
namespace qr_token {

// Maior token que o backend emite (`v1.<terminalId>.<iat>.<exp>.<hmac>`):
// prefixo 3 + terminalId ate 64 + separador + epoch de 10 digitos (iat) +
// separador + 10 (exp) + separador + assinatura HMAC-SHA256 em base64url (43).
// O backend aceita 12 digitos no regex, mas so emite epoch de 10 ate 2286.
constexpr size_t kMaxTokenBytes = 3 + 64 + 1 + 10 + 1 + 10 + 1 + 43;

struct State {
  char token[kMaxTokenBytes + 1] = {0};
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
