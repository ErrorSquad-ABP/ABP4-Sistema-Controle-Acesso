// Display OLED SSD1306 128x64 por I2C (TERMINAL_DISPLAY_OLED 1). A tela e pequena,
// entao ela mostra so o QR rotativo, no maior tamanho que cabe: fundo aceso,
// modulos apagados e escala inteira (com o token compacto, QR 29x29 em escala 2).
// Sem QR valido, uma linha curta avisa que o terminal aguarda o QR.
#include "terminal_settings.h"

#if TERMINAL_DISPLAY_OLED

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Arduino.h>
#include <Wire.h>
#include <qrcode.h>
#include <string.h>

#include "display.h"
#include "qr_version.h"

namespace {

constexpr int kWidth = 128;
constexpr int kHeight = 64;
// Margem minima de cada lado, em pixels. O fundo aceso cobre a tela toda, entao
// na horizontal a margem real e bem maior; na vertical sobra o que a escala deixar.
constexpr int kMinMarginPx = 2;

Adafruit_SSD1306 oled(kWidth, kHeight, &Wire, -1);
bool ready = false;

QRCode qr;
uint8_t qrBuffer[384];  // cobre a versao 8 (49x49 modulos)

// Ajustes de leitura, trocados em tempo de execucao pela serial (teste de bancada):
// i = inverte as cores, c = brilho baixo/alto, s = escala maxima / escala 1 com
// margem completa de 4 modulos.
bool inverted = false;
bool lowContrast = false;
bool fullQuietZone = false;

bool qrVisible = false;
char qrToken[qr_token::kMaxTokenBytes + 1] = {0};

// So redesenha (e manda ~1 KB pelo I2C) quando o token muda.
enum class Screen { none, waiting, qr };
Screen drawnScreen = Screen::none;
char drawnToken[qr_token::kMaxTokenBytes + 1] = {0};

void drawWaiting() {
  oled.clearDisplay();
  oled.setTextColor(SSD1306_WHITE);
  oled.setTextSize(1);
  oled.setCursor(22, 28);
  oled.print("aguardando QR");
}

bool drawQr(const char* token) {
  const uint8_t version = qr_version::smallestFor(strlen(token));
  if (version == 0 || qrcode_initText(&qr, qrBuffer, version, ECC_LOW, token) != 0) return false;

  const int usable = fullQuietZone ? kHeight - 2 * 4 : kHeight - 2 * kMinMarginPx;
  int scale = fullQuietZone ? 1 : usable / qr.size;
  if (scale < 1) scale = 1;
  const int side = qr.size * scale;
  const int left = (kWidth - side) / 2;
  const int top = (kHeight - side) / 2;

  oled.fillScreen(SSD1306_WHITE);
  for (uint8_t y = 0; y < qr.size; ++y) {
    for (uint8_t x = 0; x < qr.size; ++x) {
      if (qrcode_getModule(&qr, x, y)) {
        oled.fillRect(left + x * scale, top + y * scale, scale, scale, SSD1306_BLACK);
      }
    }
  }
  return true;
}

void printMode() {
  Serial.printf("[display] modo: cores %s, brilho %s, %s\n", inverted ? "invertidas" : "normais",
                lowContrast ? "baixo" : "alto", fullQuietZone ? "escala 1 + margem completa" : "escala maxima");
}

// Le uma tecla da serial e aplica o ajuste. Devolve true se o QR precisa ser redesenhado.
bool pollKeys() {
  if (!Serial.available()) return false;
  const int key = Serial.read();
  switch (key) {
    case 'i':
      inverted = !inverted;
      oled.invertDisplay(inverted);
      printMode();
      return false;
    case 'c':
      lowContrast = !lowContrast;
      oled.ssd1306_command(SSD1306_SETCONTRAST);
      oled.ssd1306_command(lowContrast ? 0x01 : 0xCF);
      printMode();
      return false;
    case 's':
      fullQuietZone = !fullQuietZone;
      printMode();
      return true;
    default:
      return false;
  }
}

}  // namespace

namespace terminal_display {

void begin() {
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  Wire.setClock(400000);
  ready = oled.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS);
  if (!ready) {
    Serial.println("[display] oled nao respondeu no I2C; confira SDA/SCL e o endereco");
    return;
  }
  Serial.println("[display] oled ssd1306 128x64 pronto (so QR); teclas: i=inverte c=brilho s=escala");
  printMode();
  oled.setTextWrap(false);
  drawWaiting();
  oled.display();
  drawnScreen = Screen::waiting;
}

// No OLED os avisos de acesso e da cancela nao aparecem: a tela fica so com o QR.
// LEDs e buzzer continuam sinalizando liberado/negado.
void showReading() {}
void showGranted() {}
void showDenied() {}
void showDoor(door_machine::State) {}

void showQr(const qr_token::State& state, uint64_t nowEpoch, bool clockValid) {
  qrVisible = qr_token::visible(state, nowEpoch, clockValid);
  if (!qrVisible) return;
  strncpy(qrToken, state.token, sizeof qrToken - 1);
  qrToken[sizeof qrToken - 1] = '\0';
}

void update() {
  if (!ready) return;
  if (pollKeys()) drawnScreen = Screen::none;
  if (qrVisible) {
    if (drawnScreen == Screen::qr && strcmp(qrToken, drawnToken) == 0) return;
    if (!drawQr(qrToken)) {
      drawWaiting();
      drawnScreen = Screen::waiting;
      drawnToken[0] = '\0';
      oled.display();
      return;
    }
    drawnScreen = Screen::qr;
    strncpy(drawnToken, qrToken, sizeof drawnToken - 1);
    drawnToken[sizeof drawnToken - 1] = '\0';
  } else {
    if (drawnScreen == Screen::waiting) return;
    drawWaiting();
    drawnScreen = Screen::waiting;
    drawnToken[0] = '\0';
  }
  oled.display();
}

}  // namespace terminal_display

#endif  // TERMINAL_DISPLAY_OLED
