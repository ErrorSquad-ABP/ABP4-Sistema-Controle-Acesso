#include <assert.h>
#include <stdio.h>

#include "feedback_pattern.h"

using feedback_pattern::Effect;
using feedback_pattern::Runner;

int main() {
  Runner runner;
  assert(!runner.active());
  assert(!runner.green());
  assert(!runner.red());
  assert(runner.toneHz() == 0);

  runner.start(Effect::granted, 1000);
  runner.update(1000);
  assert(runner.active());
  assert(runner.green());
  assert(!runner.red());
  assert(runner.toneHz() == 440);

  runner.update(1179);
  assert(runner.toneHz() == 440);
  runner.update(1180);
  assert(runner.toneHz() == 0);  // pausa entre os dois bipes
  assert(runner.green());
  runner.update(1429);
  assert(runner.toneHz() == 0);
  runner.update(1430);
  assert(runner.green());
  assert(runner.toneHz() == 659);
  runner.update(1649);
  assert(runner.active());
  runner.update(1650);
  assert(!runner.active());
  assert(!runner.green());
  assert(runner.toneHz() == 0);

  runner.start(Effect::denied, 5000);
  runner.update(5000);
  assert(runner.active());
  assert(runner.red());
  assert(!runner.green());
  assert(runner.toneHz() == 220);
  runner.update(5599);
  assert(runner.toneHz() == 220);
  runner.update(5600);
  assert(runner.red());
  assert(runner.toneHz() == 0);
  runner.update(6499);
  assert(runner.active());
  runner.update(6500);
  assert(!runner.active());
  assert(!runner.red());

  // Um novo efeito interrompe o anterior sem esperar o fim.
  runner.start(Effect::granted, 100);
  runner.update(100);
  assert(runner.green());
  runner.start(Effect::denied, 150);
  runner.update(150);
  assert(runner.red());
  assert(!runner.green());
  assert(runner.toneHz() == 220);

  // rollover de millis()
  runner.start(Effect::granted, UINT32_MAX - 100);
  runner.update(0);
  assert(runner.toneHz() == 440);

  puts("feedback: padroes granted/denied nao bloqueantes OK");
}
