#pragma once

#include <stdint.h>

class RetryInterval {
 public:
  explicit RetryInterval(uint32_t interval) : interval_(interval) {}

  bool ready(uint32_t now) {
    if (attempted_ && static_cast<uint32_t>(now - lastAttempt_) < interval_) {
      return false;
    }
    attempted_ = true;
    lastAttempt_ = now;
    return true;
  }

 private:
  uint32_t interval_;
  uint32_t lastAttempt_ = 0;
  bool attempted_ = false;
};
