#pragma once

#include <stdint.h>

// Padroes de LED e buzzer herdados do prototipo, descritos como passos com
// duracao: quem executa aplica o passo atual e nunca espera dentro do loop.
namespace feedback_pattern {

enum class Effect { none, granted, denied };

struct Step {
  uint32_t durationMs;
  bool green;
  bool red;
  uint16_t toneHz;
};

class Runner {
 public:
  void start(Effect effect, uint32_t now) {
    effect_ = effect;
    startedAt_ = now;
    now_ = now;
    active_ = effect != Effect::none;
  }

  void update(uint32_t now) {
    now_ = now;
    if (!active_) return;
    if (elapsed() >= total(effect_)) {
      active_ = false;
      effect_ = Effect::none;
    }
  }

  bool active() const { return active_; }
  bool green() const { return active_ && step().green; }
  bool red() const { return active_ && step().red; }
  uint16_t toneHz() const { return active_ ? step().toneHz : 0; }

 private:
  uint32_t elapsed() const { return now_ - startedAt_; }

  Step step() const {
    const uint32_t position = elapsed();
    uint32_t limit = 0;
    const Step* steps = pattern(effect_);
    for (uint8_t i = 0; i < count(effect_); ++i) {
      limit += steps[i].durationMs;
      if (position < limit) return steps[i];
    }
    return Step{0, false, false, 0};
  }

  static const Step* pattern(Effect effect) {
    static const Step granted[] = {
        {180, true, false, 440},
        {250, true, false, 0},
        {220, true, false, 659},
    };
    static const Step denied[] = {
        {600, false, true, 220},
        {900, false, true, 0},
    };
    return effect == Effect::denied ? denied : granted;
  }

  static uint8_t count(Effect effect) { return effect == Effect::denied ? 2 : 3; }

  static uint32_t total(Effect effect) {
    const Step* steps = pattern(effect);
    uint32_t sum = 0;
    for (uint8_t i = 0; i < count(effect); ++i) sum += steps[i].durationMs;
    return sum;
  }

  Effect effect_ = Effect::none;
  uint32_t startedAt_ = 0;
  uint32_t now_ = 0;
  bool active_ = false;
};

}  // namespace feedback_pattern
