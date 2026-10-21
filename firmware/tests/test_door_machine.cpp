#include <assert.h>
#include <stdint.h>
#include <stdio.h>

#include "door_machine.h"

using door_machine::Machine;
using door_machine::State;
using door_machine::Timing;

int main() {
  Machine door(Timing{1800, 3000});
  door.reset(1000);
  assert(door.state() == State::idle);
  assert(!door.busy());

  assert(door.requestOpen(1000));
  assert(door.state() == State::opening);
  assert(door.busy());

  // Um segundo comando nao pode interromper o movimento em andamento.
  assert(!door.update(2799));
  assert(door.state() == State::opening);
  assert(!door.requestOpen(2799));
  assert(door.state() == State::opening);

  assert(door.update(2800));
  assert(door.state() == State::open);
  assert(door.busy());
  assert(!door.requestOpen(2800));

  assert(!door.update(5799));
  assert(door.state() == State::open);
  assert(door.update(5800));
  assert(door.state() == State::closing);

  assert(!door.update(7599));
  assert(door.state() == State::closing);
  assert(door.update(7600));
  assert(door.state() == State::idle);
  assert(!door.busy());

  // Terminado o ciclo, a cancela aceita o proximo comando.
  assert(door.requestOpen(8000));
  assert(door.state() == State::opening);

  // rollover de millis() durante a abertura
  Machine rollover(Timing{1800, 3000});
  rollover.reset(UINT32_MAX - 1000);
  assert(rollover.requestOpen(UINT32_MAX - 1000));
  assert(!rollover.update(798));
  assert(rollover.state() == State::opening);
  assert(rollover.update(799));
  assert(rollover.state() == State::open);
  assert(rollover.update(3799));
  assert(rollover.state() == State::closing);

  puts("door: idle/opening/open/closing, comando recusado e rollover OK");
}
