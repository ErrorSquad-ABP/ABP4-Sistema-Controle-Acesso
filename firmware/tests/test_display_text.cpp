#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "display_text.h"

using display_text::Lines;
using display_text::Status;

namespace {

void testStatus(Status status, const char* expectedTop, const char* expectedBottom) {
  const Lines lines = display_text::render(status);
  assert(strlen(lines.top) == display_text::kColumns);
  assert(strlen(lines.bottom) == display_text::kColumns);
  assert(strcmp(lines.top, expectedTop) == 0);
  assert(strcmp(lines.bottom, expectedBottom) == 0);
}

size_t textLength(const char* text) { return strlen(text); }

}  // namespace

int main() {
  testStatus(Status::ready, "TERMINAL PRONTO ", "Aproxime a tag  ");
  testStatus(Status::reading, "LENDO TAG       ", "Aguarde...      ");
  testStatus(Status::granted, "ACESSO LIBERADO ", "Bem-vindo       ");
  testStatus(Status::denied, "ACESSO NEGADO   ", "Tente novamente ");
  testStatus(Status::opening, "ABRINDO CANCELA ", "Aguarde         ");
  testStatus(Status::open, "CANCELA ABERTA  ", "Aguarde         ");
  testStatus(Status::closing, "FECHANDO CANCELA", "Aguarde         ");

  const Status all[] = {Status::ready,   Status::reading, Status::granted, Status::denied,
                        Status::opening, Status::open,    Status::closing};
  for (size_t i = 0; i < sizeof all / sizeof all[0]; ++i) {
    const Lines first = display_text::render(all[i]);
    assert(textLength(first.top) == display_text::kColumns);
    for (size_t other = i + 1; other < sizeof all / sizeof all[0]; ++other) {
      assert(strcmp(first.top, display_text::render(all[other]).top) != 0);
    }
  }

  puts("display: textos de 16 colunas por status OK");
}
