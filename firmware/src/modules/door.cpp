#include "door.h"

#include <Arduino.h>
#include <ESP32Servo.h>

#include "terminal_settings.h"

namespace {

Servo servo;
door_machine::Machine machine(door_machine::Timing{DOOR_MOVE_MS, DOOR_HOLD_OPEN_MS});

void apply(door_machine::State state) {
  switch (state) {
    case door_machine::State::opening:
      servo.write(DOOR_SERVO_OPEN);
      break;
    case door_machine::State::closing:
      servo.write(DOOR_SERVO_CLOSE);
      break;
    case door_machine::State::open:
    case door_machine::State::idle:
      servo.write(DOOR_SERVO_STOP);
      break;
  }
}

}  // namespace

namespace terminal_door {

void begin() {
  servo.setPeriodHertz(50);
  servo.attach(DOOR_SERVO_PIN, 500, 2400);
  machine.reset(millis());
  apply(machine.state());
}

bool requestOpen() {
  if (!machine.requestOpen(millis())) return false;
  apply(machine.state());
  return true;
}

void update() {
  if (machine.update(millis())) apply(machine.state());
}

door_machine::State state() { return machine.state(); }

}  // namespace terminal_door
