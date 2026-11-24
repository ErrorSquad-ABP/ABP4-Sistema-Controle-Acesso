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
  bool observe(const char* uid, uint32_t now) { return observeValue(uid, now, true); }
  /** Prova HCE tem 32 hex; nao passa pela regra de UID de tag. */
  bool observeToken(const char* token, uint32_t now) { return observeValue(token, now, false); }
  void present(uint32_t now) { lastSeen_ = now; }
  void absent(uint32_t now, uint32_t removalMs) {
    if (now - lastSeen_ >= removalMs) uid_[0] = '\0';
  }
 private:
  bool observeValue(const char* value, uint32_t now, bool requireUid) {
    if (requireUid && !validUid(value)) return false;
    if (value == nullptr || strlen(value) >= sizeof uid_) return false;
    const bool fresh = strcmp(uid_, value) != 0;
    strcpy(uid_, value);
    lastSeen_ = now;
    return fresh;
  }
  char uid_[33] = {};
  uint32_t lastSeen_ = 0;
};
}  // namespace nfc_scan
