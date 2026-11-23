#include "display.h"
#include "terminal_settings.h"

#if !TERMINAL_LEGACY_TFT && !TERMINAL_DISPLAY_OLED
#include <Adafruit_SSD1306.h>
#include <Arduino.h>
#include <Wire.h>
#if LCD_ENABLED
#include <LiquidCrystal_I2C.h>
#endif
#include "display_text.h"

namespace {
TwoWire oledBus(1);
Adafruit_SSD1306 oled(128, 64, &oledBus, -1);
bool oledReady = false;
#if LCD_ENABLED
LiquidCrystal_I2C lcd(LCD_ADDRESS, 16, 2);
bool lcdReady = false;
#endif
display_text::Status current = display_text::Status::ready;
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
#if LCD_ENABLED
  Wire.begin(LCD_SDA_PIN, LCD_SCL_PIN);
  Wire.setTimeOut(50);
  Wire.beginTransmission(LCD_ADDRESS);
  lcdReady = Wire.endTransmission() == 0;
  if (lcdReady) { lcd.init(); lcd.backlight(); }
#endif
  Serial.println("[display] perfil NFC: status apenas; QR requer TFT");
  update();
}
void showReading() { transient(display_text::Status::reading, 1500); }
void showGranted() { transient(display_text::Status::granted, 1200); }
void showDenied() { transient(display_text::Status::denied, 2500); }
void showDoor(door_machine::State) {}
// QR v8 + quiet zone ocupa 57x57 modulos: escala 2 exige 114 pixels de altura.
// Nao truncar token nem fingir suporte QR legivel neste perfil.
void showQr(const qr_token::State&, uint64_t, bool) {}
void update() {
  if (duration && millis() - started >= duration) {
    current = display_text::Status::ready;
    duration = 0;
  }
  if (drawn && shown == current) return;
  const display_text::Lines text = display_text::render(current);
  if (oledReady) {
    oled.clearDisplay();
    oled.setCursor(0, 0); oled.print("TERMINAL NFC");
    oled.setCursor(0, 20); oled.print(text.top);
    oled.setCursor(0, 34); oled.print(text.bottom);
    oled.display();
  }
#if LCD_ENABLED
  if (lcdReady) {
    lcd.clear();
    lcd.setCursor(0, 0); lcd.print(text.top);
    lcd.setCursor(0, 1); lcd.print(text.bottom);
  }
#endif
  shown = current;
  drawn = true;
}
}
#endif
