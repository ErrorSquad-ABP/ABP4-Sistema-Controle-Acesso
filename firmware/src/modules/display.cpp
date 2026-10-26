#include "display.h"

#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <Arduino.h>
#include <qrcode.h>
#include <string.h>

#include "display_text.h"
#include "terminal_settings.h"

namespace {

// SPI por software: preserva os pinos do prototipo (servo, LEDs e buzzer).
Adafruit_ILI9341 tft(TFT_CS_PIN, TFT_DC_PIN, TFT_MOSI_PIN, TFT_SCK_PIN, TFT_RST_PIN);

constexpr int kScreenWidth = 240;
constexpr int kScreenHeight = 320;
constexpr int kStatusTop = 228;
constexpr uint8_t kQrVersion = 8;  // 49x49, ate 152 bytes em ECC_LOW (token do contrato: 128)
constexpr int kQrScale = 4;

QRCode qr;
// 49x49 = 2401 bits (~301 bytes); 384 cobre a versao 8 com folga.
uint8_t qrBuffer[384];
char drawnToken[129] = {0};
bool qrDrawn = false;
uint32_t drawnSeconds = 0;

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

void drawNoQr() {
  tft.fillRect(0, 0, kScreenWidth, kStatusTop, ILI9341_WHITE);
  tft.setTextColor(ILI9341_BLACK);
  tft.setTextSize(3);
  tft.setCursor(60, 90);
  tft.print("SEM QR");
  tft.setTextSize(1);
  tft.setCursor(40, 130);
  tft.print("Aguardando o terminal...");
  drawnToken[0] = '\0';
}

void drawQr(const char* token) {
  tft.fillRect(0, 0, kScreenWidth, kStatusTop, ILI9341_WHITE);
  if (qrcode_initText(&qr, qrBuffer, kQrVersion, ECC_LOW, token) != 0) {
    tft.setTextColor(ILI9341_BLACK);
    tft.setTextSize(2);
    tft.setCursor(20, 100);
    tft.print("QR LONGO DEMAIS");
    drawnToken[0] = '\0';
    return;
  }

  const int side = qr.size * kQrScale;
  const int left = (kScreenWidth - side) / 2;
  const int top = 4;
  for (uint8_t y = 0; y < qr.size; ++y) {
    for (uint8_t x = 0; x < qr.size; ++x) {
      if (qrcode_getModule(&qr, x, y)) {
        tft.fillRect(left + x * kQrScale, top + y * kQrScale, kQrScale, kQrScale, ILI9341_BLACK);
      }
    }
  }
  strncpy(drawnToken, token, sizeof drawnToken - 1);
  drawnToken[sizeof drawnToken - 1] = '\0';
}

void drawQrFooter(uint32_t secondsLeft) {
  tft.fillRect(0, 200, kScreenWidth, kStatusTop - 200, ILI9341_WHITE);
  tft.setTextColor(ILI9341_BLACK);
  tft.setTextSize(1);
  // O token completo esta no QR; aqui cabe so um prefixo para conferencia.
  char preview[17];
  strncpy(preview, drawnToken, sizeof preview - 1);
  preview[sizeof preview - 1] = '\0';
  tft.setCursor(8, 202);
  tft.print(preview);
  tft.setCursor(8, 214);
  tft.printf("expira em %us", static_cast<unsigned int>(secondsLeft));
}

void drawStatus(display_text::Status status) {
  const display_text::Lines lines = display_text::render(status);
  tft.fillRect(0, kStatusTop, kScreenWidth, kScreenHeight - kStatusTop, ILI9341_BLACK);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(8, kStatusTop + 12);
  tft.print(lines.top);
  tft.setCursor(8, kStatusTop + 48);
  tft.print(lines.bottom);
}

}  // namespace

namespace terminal_display {

void begin() {
  tft.begin();
  tft.setRotation(0);
  tft.setTextWrap(false);
  tft.fillScreen(ILI9341_BLACK);
  drawNoQr();
  drawStatus(display_text::Status::ready);
  drawnStatus = display_text::Status::ready;
  drawn = true;
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

void showQr(const qr_token::State& state, uint64_t nowEpoch, bool clockValid) {
  if (!qr_token::visible(state, nowEpoch, clockValid)) {
    if (qrDrawn) {
      drawNoQr();
      qrDrawn = false;
      drawnSeconds = 0;
    }
    return;
  }

  if (!qrDrawn || strcmp(state.token, drawnToken) != 0) {
    drawQr(state.token);
    qrDrawn = true;
  }
  const uint32_t secondsLeft = qr_token::secondsLeft(state, nowEpoch, clockValid);
  if (secondsLeft != drawnSeconds) {
    drawQrFooter(secondsLeft);
    drawnSeconds = secondsLeft;
  }
}

void update() {
  const display_text::Status status = active(millis());
  if (drawn && status == drawnStatus) return;
  drawStatus(status);
  drawnStatus = status;
  drawn = true;
}

}  // namespace terminal_display
