#pragma once

#include <stdint.h>

namespace display_text {

constexpr uint8_t kColumns = 16;

enum class Status { ready, reading, granted, denied, opening, open, closing };

struct Lines {
  char top[kColumns + 1];
  char bottom[kColumns + 1];
};

namespace detail {

inline void fillLine(char* out, const char* source) {
  uint8_t column = 0;
  while (column < kColumns && source[column] != '\0') {
    out[column] = source[column];
    ++column;
  }
  while (column < kColumns) out[column++] = ' ';
  out[kColumns] = '\0';
}

}  // namespace detail

inline Lines render(Status status) {
  struct Text {
    const char* top;
    const char* bottom;
  };
  static const Text texts[] = {
      {"TERMINAL PRONTO", "Aproxime a tag"},
      {"LENDO TAG", "Aguarde..."},
      {"ACESSO LIBERADO", "Bem-vindo"},
      {"ACESSO NEGADO", "Tente novamente"},
      {"ABRINDO CANCELA", "Aguarde"},
      {"CANCELA ABERTA", "Aguarde"},
      {"FECHANDO CANCELA", "Aguarde"},
  };
  const Text& text = texts[static_cast<uint8_t>(status)];

  Lines lines = {};
  detail::fillLine(lines.top, text.top);
  detail::fillLine(lines.bottom, text.bottom);
  return lines;
}

}  // namespace display_text
