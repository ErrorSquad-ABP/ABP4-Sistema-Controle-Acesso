#pragma once

#include <stddef.h>
#include <stdint.h>

// Menor versao de QR (ECC_LOW, modo byte) que comporta o token. Telas pequenas,
// como o OLED 128x64, precisam do QR com o menor numero de modulos possivel.
namespace qr_version {

// Capacidade em bytes (modo byte, ECC_LOW) das versoes 1 a 8 (ISO/IEC 18004).
constexpr size_t kByteCapacity[] = {17, 32, 53, 78, 106, 134, 154, 192};
constexpr uint8_t kMaxVersion = 8;

constexpr int modules(uint8_t version) { return 17 + 4 * version; }

// 0 quando o token nao cabe nem na versao maxima.
inline uint8_t smallestFor(size_t tokenBytes) {
  for (uint8_t version = 1; version <= kMaxVersion; ++version) {
    if (tokenBytes <= kByteCapacity[version - 1]) return version;
  }
  return 0;
}

}  // namespace qr_version
