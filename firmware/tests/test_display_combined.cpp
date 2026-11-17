#include <assert.h>
#include <stdio.h>
#include <string.h>

#include "Arduino.h"
#include "Adafruit_SSD1306.h"
#include "LiquidCrystal_I2C.h"
#include "modules/display.h"

uint32_t testNow = 0;
TestSerial Serial;
TestWire testWires[2];
TwoWire Wire(0);
TestOled testOled;
TestLcd testLcd;

void renderLcd() {
  for (int i = 0; i < 40; ++i) {
    terminal_display::update();
    testNow += 10;
  }
}

int main(int argc, char** argv) {
  const bool missingOled = argc > 1 && strcmp(argv[1], "missing-oled") == 0;
  const bool missingLcd = argc > 1 && strcmp(argv[1], "missing-lcd") == 0;
  testWires[1].present = !missingOled;
  testWires[0].present = !missingLcd;
  terminal_display::begin();
  renderLcd();
  assert(testWires[0].sda == 16 && testWires[0].scl == 17);
  assert(testWires[1].sda == 21 && testWires[1].scl == 22);
  assert(testLcd.initialized == !missingLcd);
  if (!missingLcd) {
    assert(testLcd.backlight);
    assert(strncmp(testLcd.lines[0], "TERMINAL PRONTO", 14) == 0);
  }
  qr_token::State qr;
  strcpy(qr.token, "abp4:test-terminal-token");
  qr.hasToken = true;
  qr.expiresAt = 2000;
  terminal_display::showQr(qr, 1000, true);
  terminal_display::update();
  if (!missingOled) {
    assert(testOled.bus == 1 && testOled.frames >= 2);
    int dark = 0;
    for (int i = 0; i < 128 * 64; ++i) if (testOled.pixels[i] == 0) ++dark;
    assert(dark > 100 && dark < 64 * 64);
    assert(testOled.pixels[0] == 1);
  }
  const int frames = testOled.frames;
  terminal_display::showGranted();
  renderLcd();
  if (!missingLcd) assert(strncmp(testLcd.lines[0], "ACESSO LIBERADO", 14) == 0);
  assert(testOled.frames == frames);
  terminal_display::showDoor(door_machine::State::opening);
  testNow += 1200;
  renderLcd();
  if (!missingLcd) assert(strncmp(testLcd.lines[0], "ABRINDO CANCELA", 14) == 0);
  terminal_display::showDoor(door_machine::State::closing);
  renderLcd();
  if (!missingLcd) assert(strncmp(testLcd.lines[0], "FECHANDO CANCELA", 15) == 0);
  terminal_display::showQr(qr, 2000, true);
  terminal_display::update();
  if (!missingOled) {
    assert(testOled.frames == frames + 1);
    assert(strcmp(testOled.text, "aguardando QR") == 0);
    for (int i = 0; i < 128 * 64; ++i) assert(testOled.pixels[i] == 0);
  }
  if (!missingLcd) {
    testWires[0].failAt = testWires[0].attempts + 2;
    terminal_display::showDenied();
    const uint32_t before = testNow;
    terminal_display::update();
    assert(testNow - before <= 8);
    terminal_display::update();
    const int attempts = testWires[0].attempts;
    for (int i = 0; i < 10; ++i) terminal_display::update();
    assert(testWires[0].attempts == attempts);
  }
  puts("display combinado: QR OLED e status LCD em barramentos separados, expiracao e falha isolada OK");
}
