#pragma once

namespace terminal_nfc {
using Publisher = bool (*)(const char* uid);
using HcePublisher = bool (*)(const char* token);
void setPublisher(Publisher publisher);
void setHcePublisher(HcePublisher publisher);
void begin();
void update();
}  // namespace terminal_nfc
