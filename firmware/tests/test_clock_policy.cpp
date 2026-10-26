#include <assert.h>
#include <stdio.h>

#include "clock_policy.h"

int main() {
  // Zero e epoch anterior a 2025 nao sao hora confiavel (SNTP nao respondeu).
  assert(!clock_policy::reliable(0));
  assert(!clock_policy::reliable(1735689599ULL));
  assert(clock_policy::reliable(1735689600ULL));
  assert(clock_policy::reliable(1792438213ULL));
  puts("clock_policy: janela de confianca OK");
  return 0;
}
