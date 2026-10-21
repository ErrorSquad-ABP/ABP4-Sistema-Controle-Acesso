#include "display.h"

#include <Arduino.h>
#include <LiquidCrystal_I2C.h>
#include <Wire.h>

#include "display_text.h"
#include "terminal_settings.h"

namespace {

static_assert(DISPLAY_COLUMNS == display_text::kColumns, "display_text fixa 16 colunas");
static_assert(DISPLAY_ROWS == 2, "display_text fixa 2 linhas");

LiquidCrystal_I2C lcd(DISPLAY_I2C_ADDRESS, DISPLAY_COLUMNS, DISPLAY_ROWS);

display_text::Status stickyStatus = display_text::Status::ready;
bool sticky = false;
display_text::Status transientStatus = display_text::Status::ready;
uint32_t transientStartedAt = 0;
uint32_t transientDurationMs = 0;
display_text::Status drawnStatus = display_text::Status::ready;
bool drawn = false;

display_text::Status active(uint32_t now) {
  // O aviso pontual (liberado/negado) aparece primeiro: o estado do servo
  // continua valendo depois que o aviso expira.
  if (transientDurationMs != 0 && now - transientStartedAt < transientDurationMs) {
    return transientStatus;
  }
  if (sticky) return stickyStatus;
  return display_text::Status::ready;
}

void showTransient(display_text::Status status, uint32_t durationMs) {
  transientStatus = status;
  transientStartedAt = millis();
  transientDurationMs = durationMs;
}

}  // namespace

namespace terminal_display {

void begin() {
  Wire.begin(DISPLAY_SDA_PIN, DISPLAY_SCL_PIN);
  lcd.init();
  lcd.backlight();
}

void showReading() { showTransient(display_text::Status::reading, 1500); }

void showGranted() { showTransient(display_text::Status::granted, 1200); }

void showDenied() { showTransient(display_text::Status::denied, 2500); }

void showDoor(door_machine::State state) {
  switch (state) {
    case door_machine::State::opening:
      stickyStatus = display_text::Status::opening;
      sticky = true;
      break;
    case door_machine::State::open:
      stickyStatus = display_text::Status::open;
      sticky = true;
      break;
    case door_machine::State::closing:
      stickyStatus = display_text::Status::closing;
      sticky = true;
      break;
    case door_machine::State::idle:
      sticky = false;
      break;
  }
}

void update() {
  const display_text::Status status = active(millis());
  if (drawn && status == drawnStatus) return;

  const display_text::Lines lines = display_text::render(status);
  lcd.setCursor(0, 0);
  lcd.print(lines.top);
  lcd.setCursor(0, 1);
  lcd.print(lines.bottom);
  drawnStatus = status;
  drawn = true;
}

}  // namespace terminal_display
