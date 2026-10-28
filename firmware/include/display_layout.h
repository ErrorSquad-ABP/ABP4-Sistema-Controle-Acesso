#pragma once

#include <stddef.h>
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
// Versao 8 / ECC_LOW em modo byte: 194 codewords de dados, 4 bits de modo e 8
// bits de tamanho -> floor((194 * 8 - 4 - 8) / 8) = 192 bytes.
constexpr size_t kQrByteCapacity = 192;
// 49x49 = 2401 bits (~301 bytes); 384 cobre a versao 8 com folga.
constexpr size_t kQrBufferBytes = 384;

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
