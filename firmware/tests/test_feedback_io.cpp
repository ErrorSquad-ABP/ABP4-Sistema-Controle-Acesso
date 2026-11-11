#include <assert.h>
#include <stdio.h>
#include "Arduino.h"
#include "modules/feedback.h"
#include "terminal_settings.h"

uint32_t testNow = 0;
TestSerial Serial;
uint8_t levels[40] = {};
int soundCalls = 0;
int stopCalls = 0;
bool toneStarted = false;
unsigned int frequency = 0;
void pinMode(uint8_t, uint8_t) {}
void digitalWrite(uint8_t pin, uint8_t value) { levels[pin] = value; }
void setToneChannel(uint8_t channel) { assert(channel == 4); }
void tone(uint8_t pin, unsigned int hz) {
  assert(pin == FEEDBACK_BUZZER_PIN);
  frequency = hz;
  toneStarted = true;
  ++soundCalls;
}
void noTone(uint8_t pin) {
  assert(pin == FEEDBACK_BUZZER_PIN);
  assert(toneStarted);  // LEDC nao existe antes do primeiro tone() no core 2.x.
  ++stopCalls;
  frequency = 0;
}

int main() {
  const uint8_t on = FEEDBACK_LED_ACTIVE_LOW ? LOW : HIGH;
  const uint8_t off = FEEDBACK_LED_ACTIVE_LOW ? HIGH : LOW;
  terminal_feedback::begin();
  terminal_feedback::update();
  assert(levels[FEEDBACK_RED_LED_PIN] == off);
  assert(levels[FEEDBACK_GREEN_LED_PIN] == off);
  assert(soundCalls == 0);  // Nao sinaliza sucesso na inicializacao/leitura.
  assert(stopCalls == 0);  // Nao chamar noTone() em canal LEDC nao inicializado.
  if (FEEDBACK_BUZZER_ENABLED) assert(levels[FEEDBACK_BUZZER_PIN] == LOW);
  terminal_feedback::playGranted();
  terminal_feedback::update();
  assert(levels[FEEDBACK_GREEN_LED_PIN] == on);
  assert(levels[FEEDBACK_RED_LED_PIN] == off);
  if (FEEDBACK_BUZZER_ENABLED) assert(frequency == 440);
  testNow = 180;
  terminal_feedback::update();
  assert(frequency == 0);
  testNow = 430;
  terminal_feedback::update();
  if (FEEDBACK_BUZZER_ENABLED) assert(frequency == 659);
  testNow = 650;
  terminal_feedback::update();
  assert(levels[FEEDBACK_GREEN_LED_PIN] == off);
  assert(frequency == 0);
  terminal_feedback::playDenied();
  terminal_feedback::update();
  assert(levels[FEEDBACK_RED_LED_PIN] == on);
  assert(levels[FEEDBACK_GREEN_LED_PIN] == off);
  if (FEEDBACK_BUZZER_ENABLED) assert(frequency == 220);
  testNow = 2150;
  terminal_feedback::update();
  assert(levels[FEEDBACK_RED_LED_PIN] == off);
  assert(frequency == 0);
  if (!FEEDBACK_BUZZER_ENABLED) assert(soundCalls == 0);
  puts("feedback: GPIOs, polaridade, padroes sonoros e buzzer opcional OK");
}
