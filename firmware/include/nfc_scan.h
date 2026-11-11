#pragma once

#include <stdint.h>
#include <stddef.h>
#include <string.h>

namespace nfc_scan {
inline bool formatUid(const uint8_t* bytes, size_t length, char* out, size_t capacity) {
  if (out == nullptr || capacity == 0) return false;
  out[0] = '\0';
  if (bytes == nullptr || (length != 4 && length != 7 && length != 10) ||
      capacity < length * 2 + 1) return false;
  const char* hex = "0123456789ABCDEF";
  for (size_t i = 0; i < length; ++i) {
    out[i * 2] = hex[bytes[i] >> 4];
    out[i * 2 + 1] = hex[bytes[i] & 15];
  }
  out[length * 2] = '\0';
  return true;
}

inline bool validUid(const char* uid) {
  if (uid == nullptr) return false;
  const size_t length = strlen(uid);
  if (length != 8 && length != 14 && length != 20) return false;
  return strspn(uid, "0123456789ABCDEF") == length;
}

// Uma tentativa por apresentacao, mesmo se a rede estiver indisponivel.
// WUPA detecta tambem a tag que foi colocada em HALT na leitura anterior.
class Presentation {
 public:
  bool observe(const char* uid, uint32_t now) {
    if (!validUid(uid)) return false;
    const bool fresh = strcmp(uid_, uid) != 0;
    strcpy(uid_, uid);
    lastSeen_ = now;
    return fresh;
  }
  void present(uint32_t now) { lastSeen_ = now; }
  void absent(uint32_t now, uint32_t removalMs) {
    if (now - lastSeen_ >= removalMs) uid_[0] = '\0';
  }
 private:
  char uid_[21] = {};
  uint32_t lastSeen_ = 0;
};
}  // namespace nfc_scan
