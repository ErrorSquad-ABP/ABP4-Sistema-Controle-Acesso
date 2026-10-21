#pragma once

#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>

// Conversao entre ISO 8601 UTC ("...Z") e epoch UTC. Sem fuso: o contrato v1
// so produz UTC, entao qualquer offset e recusado em vez de interpretado.
namespace iso8601 {

namespace detail {

inline bool digits(const char* text, size_t offset, size_t count, int& value) {
  int parsed = 0;
  for (size_t i = 0; i < count; ++i) {
    const char character = text[offset + i];
    if (character < '0' || character > '9') return false;
    parsed = parsed * 10 + (character - '0');
  }
  value = parsed;
  return true;
}

// Dias desde 1970-01-01 no calendario gregoriano proleptico (Hinnant).
inline int64_t daysFromCivil(int year, unsigned month, unsigned day) {
  year -= month <= 2;
  const int era = (year >= 0 ? year : year - 399) / 400;
  const unsigned yearOfEra = static_cast<unsigned>(year - era * 400);
  const unsigned dayOfYear = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
  const unsigned dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear;
  return static_cast<int64_t>(era) * 146097 + static_cast<int64_t>(dayOfEra) - 719468;
}

inline void civilFromDays(int64_t days, int& year, unsigned& month, unsigned& day) {
  days += 719468;
  const int64_t era = (days >= 0 ? days : days - 146096) / 146097;
  const unsigned dayOfEra = static_cast<unsigned>(days - era * 146097);
  const unsigned yearOfEra =
      (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365;
  const int gregorianYear = static_cast<int>(yearOfEra) + static_cast<int>(era) * 400;
  const unsigned dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100);
  const unsigned monthIndex = (5 * dayOfYear + 2) / 153;
  day = dayOfYear - (153 * monthIndex + 2) / 5 + 1;
  month = monthIndex + (monthIndex < 10 ? 3 : -9);
  year = gregorianYear + (month <= 2);
}

}  // namespace detail

inline bool toEpoch(const char* text, uint64_t& seconds) {
  if (text == nullptr) return false;
  const size_t size = strlen(text);
  if (size != 20 && size != 24) return false;
  if (text[4] != '-' || text[7] != '-' || text[10] != 'T' || text[13] != ':' || text[16] != ':' ||
      text[size - 1] != 'Z') {
    return false;
  }
  // Fracao de segundo e validada e descartada: o prazo vale em segundos.
  int fraction = 0;
  if (size == 24 && (text[19] != '.' || !detail::digits(text, 20, 3, fraction))) return false;

  int year = 0;
  int month = 0;
  int day = 0;
  int hour = 0;
  int minute = 0;
  int second = 0;
  if (!detail::digits(text, 0, 4, year) || !detail::digits(text, 5, 2, month) ||
      !detail::digits(text, 8, 2, day) || !detail::digits(text, 11, 2, hour) ||
      !detail::digits(text, 14, 2, minute) || !detail::digits(text, 17, 2, second)) {
    return false;
  }
  if (year < 1970 || month < 1 || month > 12 || day < 1 || day > 31 || hour > 23 || minute > 59 ||
      second > 59) {
    return false;
  }

  const int64_t days = detail::daysFromCivil(year, static_cast<unsigned>(month),
                                             static_cast<unsigned>(day));
  seconds = static_cast<uint64_t>(days) * 86400 + static_cast<uint64_t>(hour) * 3600 +
            static_cast<uint64_t>(minute) * 60 + static_cast<uint64_t>(second);
  return true;
}

inline bool fromEpoch(uint64_t seconds, char* out, size_t size) {
  if (out == nullptr || size < 25) return false;
  const int64_t days = static_cast<int64_t>(seconds / 86400);
  const unsigned secondOfDay = static_cast<unsigned>(seconds % 86400);
  int year = 0;
  unsigned month = 0;
  unsigned day = 0;
  detail::civilFromDays(days, year, month, day);
  snprintf(out, size, "%04d-%02u-%02uT%02u:%02u:%02u.000Z", year, month, day, secondOfDay / 3600,
           (secondOfDay / 60) % 60, secondOfDay % 60);
  return true;
}

}  // namespace iso8601
