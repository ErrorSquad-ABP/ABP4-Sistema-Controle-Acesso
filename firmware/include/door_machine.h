#pragma once

#include <stdint.h>

namespace door_machine {

enum class State { idle, opening, open, closing };

struct Timing {
  uint32_t moveMs;
  uint32_t holdOpenMs;
};

// Maquina de estados com tempo injetado: o servo e de rotacao continua, entao a
// posicao vem da duracao do pulso, nunca de uma posicao angular lida de volta.
class Machine {
 public:
  explicit Machine(const Timing& timing) : timing_(timing) {}

  void reset(uint32_t now) {
    state_ = State::idle;
    changedAt_ = now;
  }

  bool requestOpen(uint32_t now) {
    if (state_ != State::idle) return false;
    state_ = State::opening;
    changedAt_ = now;
    return true;
  }

  bool update(uint32_t now) {
    const uint32_t elapsed = now - changedAt_;
    switch (state_) {
      case State::opening:
        if (elapsed < timing_.moveMs) return false;
        state_ = State::open;
        changedAt_ = now;
        return true;
      case State::open:
        if (elapsed < timing_.holdOpenMs) return false;
        state_ = State::closing;
        changedAt_ = now;
        return true;
      case State::closing:
        if (elapsed < timing_.moveMs) return false;
        state_ = State::idle;
        changedAt_ = now;
        return true;
      case State::idle:
        return false;
    }
    return false;
  }

  State state() const { return state_; }
  bool busy() const { return state_ != State::idle; }

 private:
  Timing timing_;
  State state_ = State::idle;
  uint32_t changedAt_ = 0;
};

}  // namespace door_machine
