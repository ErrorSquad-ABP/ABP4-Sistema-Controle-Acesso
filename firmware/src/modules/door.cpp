#include "door.h"

#include <Arduino.h>
#include <ESP32Servo.h>

#include "terminal_settings.h"

namespace {

Servo servo;
door_machine::Machine machine(door_machine::Timing{DOOR_MOVE_MS, DOOR_HOLD_OPEN_MS});

// Servo de rotacao continua: qualquer pulso fora do neutro exato faz o eixo
// girar. Parado, o pino fica sem pulso (detach), entao o servo nao arrasta
// mesmo que o neutro dele nao seja 1500 us.
void move(int value) {
  if (!servo.attached()) {
    servo.setPeriodHertz(50);
    servo.attach(DOOR_SERVO_PIN, DOOR_SERVO_MIN_US, DOOR_SERVO_MAX_US);
  }
  servo.write(value);
}

void stop() {
  if (!servo.attached()) return;
  servo.write(DOOR_SERVO_STOP);
  servo.detach();
  digitalWrite(DOOR_SERVO_PIN, LOW);
}

void apply(door_machine::State state) {
  switch (state) {
    case door_machine::State::opening:
      move(DOOR_SERVO_OPEN);
      break;
    case door_machine::State::closing:
      move(DOOR_SERVO_CLOSE);
      break;
    case door_machine::State::open:
    case door_machine::State::idle:
      stop();
      break;
  }
}

}  // namespace

namespace terminal_door {

void begin() {
  // Sem attach no boot: o servo so recebe pulso enquanto a cancela se move.
  pinMode(DOOR_SERVO_PIN, OUTPUT);
  digitalWrite(DOOR_SERVO_PIN, LOW);
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
