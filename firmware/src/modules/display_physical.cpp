#include "display.h"
#include "terminal_settings.h"

#if !TERMINAL_LEGACY_TFT || TERMINAL_DISPLAY_OLED
#include <Adafruit_SSD1306.h>
#include <Arduino.h>
#include <Wire.h>
#if LCD_ENABLED
#include <LiquidCrystal_I2C.h>
#endif
#include "display_text.h"

namespace {
#if !TERMINAL_DISPLAY_OLED
TwoWire oledBus(1);
Adafruit_SSD1306 oled(128, 64, &oledBus, -1);
bool oledReady = false;
#endif
#if LCD_ENABLED
LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);
bool lcdReady = false;
display_text::Lines lcdText = {};
uint8_t lcdStep = 34;

void updateLcd() {
  if (!lcdReady || lcdStep >= 34) return;
  Wire.beginTransmission(LCD_ADDRESS);
  if (Wire.endTransmission() != 0) {
    lcdReady = false;
    Serial.println("[display] LCD perdeu resposta; desabilitado ate reiniciar");
    return;
  }
  // Um byte do LCD usa seis transmissoes; limitar a um por loop com timeout de 1 ms.
  if (lcdStep == 0) lcd.setCursor(0, 0);
  else if (lcdStep == 17) lcd.setCursor(0, 1);
  else lcd.print(lcdStep < 17 ? lcdText.top[lcdStep - 1] : lcdText.bottom[lcdStep - 18]);
  ++lcdStep;
}
#endif
display_text::Status current = display_text::Status::ready;
display_text::Status doorStatus = display_text::Status::ready;
display_text::Status shown = display_text::Status::ready;
bool drawn = false;
uint32_t started = 0;
uint32_t duration = 0;

void transient(display_text::Status value, uint32_t ms) {
  current = value;
  started = millis();
  duration = ms;
}
}

namespace terminal_display {
void begin() {
#if TERMINAL_DISPLAY_OLED
  terminal_oled_qr::begin();
#else
  oledBus.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  oledBus.setTimeOut(50);
  oledBus.beginTransmission(OLED_ADDRESS);
  const bool present = oledBus.endTransmission() == 0;
  // periphBegin=false preserva os GPIOs do barramento secundario.
  oledReady = present && oled.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS, true, false);
  if (oledReady) {
    oled.setTextColor(SSD1306_WHITE);
    oled.setTextSize(1);
    oled.setTextWrap(false);
  } else {
    Serial.println("[display] OLED indisponivel");
  }
#endif
#if LCD_ENABLED
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  Wire.setTimeOut(1);
  Wire.beginTransmission(LCD_ADDRESS);
  lcdReady = Wire.endTransmission() == 0;
  if (lcdReady) { lcd.init(); lcd.backlight(); }
  Serial.println(lcdReady ? "[display] LCD 16x2 pronto" : "[display] LCD indisponivel; confira I2C/endereco");
#endif
  Serial.println(TERMINAL_DISPLAY_OLED ? "[display] perfil QR no OLED + status no LCD"
                                     : "[display] perfil NFC: status no OLED/LCD");
  update();
}
void showReading() { transient(display_text::Status::reading, 1500); }
void showGranted() { transient(display_text::Status::granted, 1200); }
void showDenied() { transient(display_text::Status::denied, 2500); }
void showDoor(door_machine::State state) {
  switch (state) {
    case door_machine::State::opening: doorStatus = display_text::Status::opening; break;
    case door_machine::State::open: doorStatus = display_text::Status::open; break;
    case door_machine::State::closing: doorStatus = display_text::Status::closing; break;
    case door_machine::State::idle: doorStatus = display_text::Status::ready; break;
  }
}
void showQr(const qr_token::State& state, uint64_t nowEpoch, bool clockValid) {
#if TERMINAL_DISPLAY_OLED
  terminal_oled_qr::showQr(state, nowEpoch, clockValid);
#else
  (void)state;
  (void)nowEpoch;
  (void)clockValid;
#endif
}
void update() {
#if TERMINAL_DISPLAY_OLED
  terminal_oled_qr::update();
#endif
  if (duration && millis() - started >= duration) {
    duration = 0;
  }
  const display_text::Status active = duration ? current : doorStatus;
  if (!drawn || shown != active) {
#if !TERMINAL_DISPLAY_OLED || LCD_ENABLED
    const display_text::Lines text = display_text::render(active);
#endif
#if !TERMINAL_DISPLAY_OLED
    if (oledReady) {
      oled.clearDisplay();
      oled.setCursor(0, 0); oled.print("TERMINAL NFC");
      oled.setCursor(0, 20); oled.print(text.top);
      oled.setCursor(0, 34); oled.print(text.bottom);
      oled.display();
    }
#endif
#if LCD_ENABLED
    lcdText = text;
    lcdStep = 0;
#endif
    shown = active;
    drawn = true;
  }
#if LCD_ENABLED
  updateLcd();
#endif
}
}
#endif
