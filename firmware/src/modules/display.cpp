#include "display.h"

#include <Adafruit_GFX.h>
#include <Adafruit_ILI9341.h>
#include <Arduino.h>
#include <qrcode.h>
#include <string.h>

#include "display_layout.h"
#include "display_text.h"
#include "terminal_settings.h"

namespace {

// SPI por software: preserva os pinos do prototipo (servo, LEDs e buzzer).
Adafruit_ILI9341 tft(TFT_CS_PIN, TFT_DC_PIN, TFT_MOSI_PIN, TFT_SCK_PIN, TFT_RST_PIN);

namespace layout = display_layout;
static_assert(layout::quietZoneFits(), "QR sem margem de silencio ou fora da tela");
// O maior token que o backend emite precisa caber inteiro no QR v8/ECC_LOW.
static_assert(qr_token::kMaxTokenBytes <= layout::kQrByteCapacity,
              "maior token do backend nao cabe no QR");

QRCode qr;
uint8_t qrBuffer[layout::kQrBufferBytes];
char drawnToken[qr_token::kMaxTokenBytes + 1] = {0};
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
  tft.fillRect(0, 0, layout::kWidth, layout::kStatusTop, ILI9341_WHITE);
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
  tft.fillRect(0, 0, layout::kWidth, layout::kStatusTop, ILI9341_WHITE);
  if (qrcode_initText(&qr, qrBuffer, layout::kQrVersion, ECC_LOW, token) != 0) {
    tft.setTextColor(ILI9341_BLACK);
    tft.setTextSize(2);
    tft.setCursor(20, 100);
    tft.print("QR LONGO DEMAIS");
    drawnToken[0] = '\0';
    return;
  }

  const int side = qr.size * layout::kQrScale;
  const int left = (layout::kWidth - side) / 2;
  const int top = layout::kQrTop;
  for (uint8_t y = 0; y < qr.size; ++y) {
    for (uint8_t x = 0; x < qr.size; ++x) {
      if (qrcode_getModule(&qr, x, y)) {
        tft.fillRect(left + x * layout::kQrScale, top + y * layout::kQrScale, layout::kQrScale, layout::kQrScale, ILI9341_BLACK);
      }
    }
  }
  strncpy(drawnToken, token, sizeof drawnToken - 1);
  drawnToken[sizeof drawnToken - 1] = '\0';
}

void drawQrFooter(uint32_t secondsLeft) {
  tft.fillRect(0, layout::kFooterTop, layout::kWidth, layout::kStatusTop - layout::kFooterTop, ILI9341_WHITE);
  tft.setTextColor(ILI9341_BLACK);
  tft.setTextSize(1);
  // O token completo esta no QR; aqui cabe so um prefixo para conferencia.
  char preview[17];
  strncpy(preview, drawnToken, sizeof preview - 1);
  preview[sizeof preview - 1] = '\0';
  tft.setCursor(8, layout::kFooterTop + layout::kFooterTokenLine);
  tft.print(preview);
  tft.setCursor(8, layout::kFooterTop + layout::kFooterCountdownLine);
  tft.printf("expira em %us", static_cast<unsigned int>(secondsLeft));
}

void drawStatus(display_text::Status status) {
  const display_text::Lines lines = display_text::render(status);
  tft.fillRect(0, layout::kStatusTop, layout::kWidth, layout::kHeight - layout::kStatusTop, ILI9341_BLACK);
  tft.setTextColor(ILI9341_WHITE);
  tft.setTextSize(2);
  tft.setCursor(8, layout::kStatusTop + layout::kStatusTopLine);
  tft.print(lines.top);
  tft.setCursor(8, layout::kStatusTop + layout::kStatusBottomLine);
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

