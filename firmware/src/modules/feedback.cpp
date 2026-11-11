#include "feedback.h"

#include <Arduino.h>

#include "feedback_pattern.h"
#include "terminal_settings.h"

namespace {

feedback_pattern::Runner runner;
bool greenLit = false;
bool redLit = false;
uint16_t buzzerHz = 0;

constexpr uint8_t kLedOnLevel = FEEDBACK_LED_ACTIVE_LOW ? LOW : HIGH;
constexpr uint8_t kLedOffLevel = FEEDBACK_LED_ACTIVE_LOW ? HIGH : LOW;

void applyLed(uint8_t pin, bool lit, bool& applied) {
  if (lit == applied) return;
  digitalWrite(pin, lit ? kLedOnLevel : kLedOffLevel);
  applied = lit;
}

}  // namespace

namespace terminal_feedback {

void begin() {
  if (FEEDBACK_BUZZER_ENABLED) setToneChannel(FEEDBACK_TONE_CHANNEL);
  // Precarregar o nivel apagado antes de habilitar saida (anodo comum).
  digitalWrite(FEEDBACK_RED_LED_PIN, kLedOffLevel);
  digitalWrite(FEEDBACK_GREEN_LED_PIN, kLedOffLevel);
  pinMode(FEEDBACK_RED_LED_PIN, OUTPUT);
  pinMode(FEEDBACK_GREEN_LED_PIN, OUTPUT);
  if (FEEDBACK_BUZZER_ENABLED) {
    // O core 2.x ainda nao inicializou LEDC antes do primeiro tone().
    // noTone() aqui tenta usar o canal inexistente; manter o piezo em LOW.
    digitalWrite(FEEDBACK_BUZZER_PIN, LOW);
    pinMode(FEEDBACK_BUZZER_PIN, OUTPUT);
  }
}

void playGranted() { runner.start(feedback_pattern::Effect::granted, millis()); }

void playDenied() { runner.start(feedback_pattern::Effect::denied, millis()); }

void update() {
  runner.update(millis());
  applyLed(FEEDBACK_GREEN_LED_PIN, runner.green(), greenLit);
  applyLed(FEEDBACK_RED_LED_PIN, runner.red(), redLit);

  const uint16_t frequency = runner.toneHz();
  if (!FEEDBACK_BUZZER_ENABLED) return;
  if (frequency == buzzerHz) return;
  if (frequency == 0) {
    noTone(FEEDBACK_BUZZER_PIN);
  } else {
    tone(FEEDBACK_BUZZER_PIN, frequency);
  }
  buzzerHz = frequency;
}

}  // namespace terminal_feedback
