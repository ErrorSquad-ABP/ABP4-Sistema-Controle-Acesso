#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "display_layout.h"
#include "qrcode.h"
#include "qr_token.h"

// Token real emitido pelo backend para um terminal de 64 caracteres.
static const char* kLongestToken =
    "v1.t-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.1793153400.1793153410."
    "NKjxidR9EvCwa6LoOTT8ftfKSM5J4oGppKQe9QLKZP0";

// Mesmo token com o ultimo caractere trocado: se o encoder truncasse o fim, a
// matriz do QR seria identica.
static const char* kAlteredLastChar =
    "v1.t-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.1793153400.1793153410."
    "NKjxidR9EvCwa6LoOTT8ftfKSM5J4oGppKQe9QLKZP1";

static_assert(qr_token::kMaxTokenBytes <= display_layout::kQrByteCapacity,
              "maior token do backend nao cabe no QR v8/ECC_LOW");

// Compara os modulos desenhados pelo encoder real para dois textos.
static int differences(const char* left, const char* right) {
  uint8_t leftBuffer[display_layout::kQrBufferBytes] = {0};
  uint8_t rightBuffer[display_layout::kQrBufferBytes] = {0};
  QRCode leftCode{};
  QRCode rightCode{};
  if (qrcode_initText(&leftCode, leftBuffer, display_layout::kQrVersion, ECC_LOW, left) != 0) return -1;
  if (qrcode_initText(&rightCode, rightBuffer, display_layout::kQrVersion, ECC_LOW, right) != 0) return -1;

  int total = 0;
  for (uint8_t y = 0; y < leftCode.size; ++y) {
    for (uint8_t x = 0; x < leftCode.size; ++x) {
      if (qrcode_getModule(&leftCode, x, y) != qrcode_getModule(&rightCode, x, y)) ++total;
    }
  }
  return total;
}

int main() {
  assert(strlen(kLongestToken) == qr_token::kMaxTokenBytes);
  assert(strlen(kAlteredLastChar) == qr_token::kMaxTokenBytes);
  assert(display_layout::kQrBufferBytes >= qrcode_getBufferSize(display_layout::kQrVersion));

  uint8_t buffer[display_layout::kQrBufferBytes] = {0};
  QRCode code{};
  assert(qrcode_initText(&code, buffer, display_layout::kQrVersion, ECC_LOW, kLongestToken) == 0);
  assert(code.size == display_layout::kQrModules);
  assert(code.version == display_layout::kQrVersion);

  // Renderizacao completa: o ultimo byte do maior token chega ao QR.
  assert(differences(kLongestToken, kAlteredLastChar) > 0);

  // Acima da capacidade o encoder trunca em silencio (o fim do texto nao muda o
  // QR). Por isso o limite e imposto no cache e garantido por static_assert, nao
  // em tempo de execucao.
  char tooLong[211];
  memset(tooLong, 'a', sizeof tooLong - 1);
  tooLong[sizeof tooLong - 1] = '\0';
  char tooLongAltered[211];
  memcpy(tooLongAltered, tooLong, sizeof tooLongAltered);
  tooLongAltered[sizeof tooLongAltered - 2] = 'b';
  assert(differences(tooLong, tooLongAltered) == 0);

  puts("display_qr: maior token renderizado por inteiro no QR v8 OK");
  return 0;
}
