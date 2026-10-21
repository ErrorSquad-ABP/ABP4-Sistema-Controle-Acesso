#include "clock_time.h"

#include <Arduino.h>
#include <time.h>

#include "terminal_settings.h"

namespace clock_time {

void begin() { configTime(0, 0, NTP_SERVER_PRIMARY, NTP_SERVER_SECONDARY); }

uint64_t nowEpoch() {
  const time_t now = time(nullptr);
  return now > 0 ? static_cast<uint64_t>(now) : 0;
}

}  // namespace clock_time
