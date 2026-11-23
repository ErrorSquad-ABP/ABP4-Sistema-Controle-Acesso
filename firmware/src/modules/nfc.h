#pragma once

namespace terminal_nfc {
using Publisher = bool (*)(const char* uid);
void setPublisher(Publisher publisher);
void begin();
void update();
}
