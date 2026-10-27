#include <assert.h>
#include <stdio.h>

#include "display_layout.h"

// A margem de silencio do QR e de 4 modulos em todos os lados; o layout fixa
// tudo em tempo de compilacao, entao um valor errado quebra o build.
static_assert(display_layout::quietZoneFits(), "QR sem margem de silencio ou fora da tela");
static_assert(display_layout::kStatusTop + display_layout::kStatusBottomLine + 16 <=
                  display_layout::kHeight,
              "status nao cabe abaixo do QR");

int main() {
  assert(display_layout::kQrSide == display_layout::kQrModules * display_layout::kQrScale);
  assert(display_layout::kQrTop >= display_layout::kQuietZone);
  assert((display_layout::kWidth - display_layout::kQrSide) / 2 >= display_layout::kQuietZone);
  assert(display_layout::kFooterTop >= display_layout::kQrBottom + display_layout::kQuietZone);
  assert(display_layout::kStatusTop >= display_layout::kFooterTop);
  puts("display_layout: margem do QR e status OK");
  return 0;
}
