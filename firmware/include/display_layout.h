#pragma once

#include <stdint.h>

// Geometria do TFT em tempo de compilacao: o QR precisa de 4 modulos de margem
// livre em todos os lados (DENSO) e o status nao pode invadir o rodape.
namespace display_layout {

constexpr int kWidth = 240;
constexpr int kHeight = 320;

constexpr uint8_t kQrVersion = 8;
constexpr int kQrModules = 49;  // 21 + 4 * (versao - 1)
constexpr int kQrScale = 4;
constexpr int kQrTop = 16;
constexpr int kQuietZone = 4 * kQrScale;
constexpr int kQrSide = kQrModules * kQrScale;
constexpr int kQrBottom = kQrTop + kQrSide;

constexpr int kFooterTop = kQrBottom + kQuietZone;
constexpr int kFooterTokenLine = 2;
constexpr int kFooterCountdownLine = 14;

constexpr int kStatusTop = 256;
constexpr int kStatusTopLine = 8;
constexpr int kStatusBottomLine = 40;

constexpr bool quietZoneFits() {
  return kQrTop >= kQuietZone && (kWidth - kQrSide) / 2 >= kQuietZone &&
         kFooterTop == kQrBottom + kQuietZone && kStatusTop >= kFooterTop;
}

}  // namespace display_layout
