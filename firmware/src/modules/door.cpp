#include "door.h"

#include <Arduino.h>
#include <ESP32Servo.h>

#include "terminal_settings.h"

namespace {

Servo servo;
door_machine::Machine machine(door_machine::Timing{DOOR_MOVE_MS, DOOR_HOLD_OPEN_MS});

#if DOOR_SERVO_POSITIONAL
static_assert(DOOR_SERVO_OPEN >= 0 && DOOR_SERVO_OPEN <= 180 &&
              DOOR_SERVO_CLOSE >= 0 && DOOR_SERVO_CLOSE <= 180,
              "Angulos do servo posicional devem estar entre 0 e 180");
#endif

void move(int value) {
  if (!servo.attached()) {
    servo.setPeriodHertz(50);
    servo.attach(DOOR_SERVO_PIN, DOOR_SERVO_MIN_US, DOOR_SERVO_MAX_US);
  }
  servo.write(value);
}

void stop() {
  if (!servo.attached()) return;
#if !DOOR_SERVO_POSITIONAL
  servo.write(DOOR_SERVO_STOP);
#endif
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
#if DOOR_SERVO_POSITIONAL
      break;
#endif
    case door_machine::State::idle:
      stop();
      break;
  }
}

}  // namespace

namespace terminal_door {

void begin() {
#if DOOR_ENABLED
  // Sem attach no boot: o servo so recebe pulso enquanto a cancela se move.
  pinMode(DOOR_SERVO_PIN, OUTPUT);
  digitalWrite(DOOR_SERVO_PIN, LOW);
  machine.reset(millis());
  apply(machine.state());
  Serial.println(DOOR_SERVO_POSITIONAL ? "[door] servo posicional habilitado; sem movimento no boot"
                                     : "[door] servo continuo habilitado; sem movimento no boot");
#else
  Serial.println("[door] servo desabilitado: somente feedback de decisao");
#endif
}

bool requestOpen() {
  if (!DOOR_ENABLED) return false;
  if (!machine.requestOpen(millis())) return false;
  apply(machine.state());
  return true;
}

void update() {
  if (!DOOR_ENABLED) return;
  if (machine.update(millis())) apply(machine.state());
}

door_machine::State state() { return machine.state(); }

}  // namespace terminal_door
