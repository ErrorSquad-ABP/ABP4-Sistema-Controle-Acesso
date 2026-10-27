#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "qr_token.h"

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

  puts("qr_token: validade e relogio OK");
  return 0;
}
