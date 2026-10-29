#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "qr_token.h"

// Token real emitido pelo backend para um terminal de 64 caracteres (DT-19).
static const char* kLongestToken =
    "v1.t-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.1793153400.1793153410."
    "NKjxidR9EvCwa6LoOTT8ftfKSM5J4oGppKQe9QLKZP0";

int main() {
  qr_token::State state{};
  strcpy(state.token, "b1c2d3e4f5a6");
  state.expiresAt = 1000;
  state.hasToken = true;

  // Visivel ate o segundo anterior ao vencimento.
  assert(qr_token::visible(state, 995, true));
  assert(qr_token::secondsLeft(state, 995, true) == 5);
  assert(!qr_token::visible(state, 1000, true));  // expirado no limite
  assert(!qr_token::visible(state, 995, false));  // sem relogio confiavel

  state.hasToken = false;
  assert(!qr_token::visible(state, 995, true));

  state.hasToken = true;
  state.token[0] = '\0';
  assert(!qr_token::visible(state, 995, true));

  // DT-19: o cache comporta o maior token emitido pelo backend, com terminador.
  static_assert(qr_token::kMaxTokenBytes == 133, "limite do token diverge do contrato do backend");
  static_assert(sizeof(qr_token::State::token) == qr_token::kMaxTokenBytes + 1,
                "buffer do token sem espaco para o terminador");
  assert(strlen(kLongestToken) == qr_token::kMaxTokenBytes);

  qr_token::State full{};
  strncpy(full.token, kLongestToken, sizeof full.token - 1);
  full.expiresAt = 1000;
  full.hasToken = true;
  assert(strlen(full.token) == 133);  // nada truncado
  assert(qr_token::visible(full, 995, true));

  puts("qr_token: validade, relogio e capacidade do maior token OK");
  return 0;
}
