#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "retry_interval.h"

int main() {
  RetryInterval retry(5000);
  assert(retry.ready(0));
  assert(!retry.ready(0));
  assert(!retry.ready(4999));
  assert(retry.ready(5000));
  assert(!retry.ready(5001));
  assert(retry.ready(10000));

  RetryInterval lateBoot(5000);
  assert(lateBoot.ready(12000));
  assert(!lateBoot.ready(16999));
  assert(lateBoot.ready(17000));

  RetryInterval rollover(5000);
  assert(rollover.ready(UINT32_MAX - 1000));
  assert(!rollover.ready(3998));
  assert(rollover.ready(3999));

  puts("retry: inicio, espera, limite e rollover OK");
}
