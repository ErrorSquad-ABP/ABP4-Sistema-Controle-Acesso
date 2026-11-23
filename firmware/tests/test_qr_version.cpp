// Host test: g++ -std=c++11 -Wall -Wextra -Werror -I include tests/test_qr_version.cpp
#include <cstdio>
#include <cstdlib>
#include <cstring>

#include "qr_token.h"
#include "qr_version.h"

static int failures = 0;

static void expect(bool condition, const char* message) {
  if (!condition) {
    std::printf("FALHOU: %s\n", message);
    ++failures;
  }
}

int main() {
  expect(qr_version::smallestFor(1) == 1, "1 byte cabe na versao 1");
  expect(qr_version::smallestFor(17) == 1, "17 bytes ainda cabem na versao 1");
  expect(qr_version::smallestFor(18) == 2, "18 bytes vao para a versao 2");
  expect(qr_version::smallestFor(192) == 8, "192 bytes cabem na versao 8");
  expect(qr_version::smallestFor(193) == 0, "193 bytes nao cabem");

  // Token compacto do terminal-dev-01: v1.<id>.<iat>.<ttl>.<hmac 96 bits base64url>.
  const char* token = "v1.terminal-dev-01.1794271079.25.abcdefghijklmnop";
  expect(std::strlen(token) == 49, "token de exemplo tem 49 bytes");
  expect(qr_version::smallestFor(std::strlen(token)) == 3, "token do terminal-dev-01 usa a versao 3");
  expect(qr_version::modules(3) == 29, "versao 3 tem 29 modulos");
  // No OLED (64 px, margem minima de 2 px) a versao 3 sai em escala 2: 58 px.
  expect((64 - 2 * 2) / qr_version::modules(3) == 2, "versao 3 cabe em escala 2 no OLED");

  // O maior token do backend precisa caber; no OLED de 64 px de altura a versao 8
  // (49 modulos) ainda cabe em escala 1 com margem de 7 px.
  expect(qr_version::smallestFor(qr_token::kMaxTokenBytes) != 0, "maior token do backend cabe");
  expect(qr_version::modules(qr_version::smallestFor(qr_token::kMaxTokenBytes)) <= 64 - 2 * 4,
         "maior QR cabe na altura do OLED com margem de 4 px");

  const char* compact = "00482439167562615602613664743089338165947";
  expect(std::strlen(compact) == 41, "token compacto tem 41 digitos");
  expect(qr_version::forText(compact) == 1, "41 digitos usam a versao 1");
  expect(qr_version::modules(qr_version::forText(compact)) == 21, "versao 1 tem 21 modulos");
  expect(64 / (qr_version::modules(qr_version::forText(compact)) + 8) == 2,
         "QR v1 comporta escala 2 com margem completa no OLED");
  expect(qr_version::forText("1234") == 1, "quatro digitos continuam numericos");
  // 18 digitos cabem na v1 pelo modo numerico; texto misto mantem a estimativa
  // conservadora por bytes.
  expect(qr_version::smallestFor(18) == 2, "18 bytes pelo limite conservador usam v2");
  expect(qr_version::forText("123456789012345678") == 1, "18 digitos usam o modo numerico");
  expect(qr_version::forText("123456789012345678a") == 2, "texto misto mantem a estimativa por bytes");
  expect(qr_version::forText("123456789012345678901234567890123456789012") != 1,
         "42 digitos nao forcam a versao 1");

  if (failures == 0) std::printf("test_qr_version: ok\n");
  return failures == 0 ? EXIT_SUCCESS : EXIT_FAILURE;
}
