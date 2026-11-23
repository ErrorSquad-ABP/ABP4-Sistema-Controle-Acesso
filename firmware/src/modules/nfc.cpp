#include "nfc.h"

#include <Arduino.h>
#include <MFRC522Extended.h>
#include <SPI.h>
#include <string.h>

#include "nfc_scan.h"
#include "retry_interval.h"
#include "terminal_settings.h"

namespace {
terminal_nfc::Publisher publisher = nullptr;
terminal_nfc::HcePublisher hcePublisher = nullptr;
#if NFC_ENABLED
MFRC522Extended reader(NFC_SS_PIN, NFC_RST_PIN);
RetryInterval poll(NFC_POLL_MS);
nfc_scan::Presentation presentation;
bool available = false;

constexpr uint8_t kSelectAid[] = {0x00, 0xA4, 0x04, 0x00, 0x08, 0xF0, 0x41,
                                  0x42, 0x50, 0x34, 0x44, 0x4D, 0x01, 0x00};
constexpr size_t kHceTokenBytes = 16;
constexpr char kHex[] = "0123456789abcdef";

bool readHceToken(MFRC522Extended::TagInfo& tag, char* token, size_t capacity) {
  if (capacity < kHceTokenBytes * 2 + 1) return false;
  // O leitor precisa de folga depois do ATS e de ganho maximo para o celular.
  reader.PCD_SetAntennaGain(reader.RxGain_max);
  delay(10);
  MFRC522::StatusCode status = MFRC522::STATUS_ERROR;
  uint8_t length = 0;
  uint8_t lastStatusWord[2] = {};
  for (uint8_t attempt = 1; attempt <= 3; ++attempt) {
    uint8_t reply[40] = {};
    length = sizeof reply;
    uint8_t apdu[sizeof kSelectAid];
    memcpy(apdu, kSelectAid, sizeof kSelectAid);
    status = reader.TCL_Transceive(&tag, apdu, sizeof apdu, reply, &length);
    if (status == MFRC522::STATUS_OK && length == kHceTokenBytes + 2 &&
        reply[kHceTokenBytes] == 0x90 && reply[kHceTokenBytes + 1] == 0x00) {
      for (size_t i = 0; i < kHceTokenBytes; ++i) {
        token[i * 2] = kHex[reply[i] >> 4];
        token[i * 2 + 1] = kHex[reply[i] & 0x0F];
      }
      token[kHceTokenBytes * 2] = '\0';
      return true;
    }
    lastStatusWord[0] = reply[0];
    lastStatusWord[1] = length > 1 ? reply[1] : 0;
    delay(30);
  }
  static uint32_t lastLog = 0;
  if (millis() - lastLog >= 2000U) {
    lastLog = millis();
    Serial.printf("[nfc] APDU falhou status=%u len=%u sw=%02X%02X\n",
                  static_cast<unsigned>(status), static_cast<unsigned>(length),
                  lastStatusWord[0], lastStatusWord[1]);
  }
  return false;
}
#endif
}  // namespace

namespace terminal_nfc {
void setPublisher(Publisher value) { publisher = value; }
void setHcePublisher(HcePublisher value) { hcePublisher = value; }

void begin() {
#if NFC_ENABLED
  SPI.begin(NFC_SCK_PIN, NFC_MISO_PIN, NFC_MOSI_PIN, NFC_SS_PIN);
  reader.PCD_Init();
  const uint8_t version = reader.PCD_ReadRegister(MFRC522::VersionReg);
  available = version != 0 && version != 0xFF;
  reader.PCD_AntennaOn();
  reader.PCD_SetAntennaGain(reader.RxGain_max);
  Serial.printf("[nfc] RC522 %s version=0x%02X tx=0x%02X\n",
                available ? "pronto" : "indisponivel; confira SPI/alimentacao", version,
                reader.PCD_ReadRegister(MFRC522::TxControlReg));
#else
  Serial.println("[nfc] desabilitado no perfil TFT legado");
#endif
}

void update() {
#if NFC_ENABLED
  static uint32_t nextCheck = 0;
  if (static_cast<int32_t>(millis() - nextCheck) >= 0) {
    nextCheck = millis() + 2000U;
    const uint8_t version = reader.PCD_ReadRegister(MFRC522::VersionReg);
    bool responding = version != 0 && version != 0xFF;
    if (responding && !available) {
      reader.PCD_Init();
      const uint8_t initializedVersion = reader.PCD_ReadRegister(MFRC522::VersionReg);
      responding = initializedVersion != 0 && initializedVersion != 0xFF;
    }
    if (responding) reader.PCD_AntennaOn();
    if (responding != available) {
      available = responding;
      Serial.println(responding ? "[nfc] RC522 voltou a responder"
                                : "[nfc] RC522 parou de responder (SPI/energia)");
    }
  }
  if (!available || !poll.ready(millis())) return;

  uint8_t atqa[2] = {};
  uint8_t size = sizeof atqa;
  static uint32_t lastField = 0;
  static uint32_t lastReinit = 0;
  const MFRC522::StatusCode status = reader.PICC_WakeupA(atqa, &size);
  if (status == MFRC522::STATUS_TIMEOUT) {
    // Sem campo por varios segundos: reinicializa o leitor uma vez por janela.
    if (millis() - lastField >= 5000U && millis() - lastReinit >= 5000U) {
      reader.PCD_Init();
      reader.PCD_AntennaOn();
      reader.PCD_SetAntennaGain(reader.RxGain_max);
      lastReinit = millis();
      Serial.println("[nfc] reinit RC522 (campo sem resposta)");
    }
    presentation.absent(millis(), NFC_REMOVAL_MS);
    return;
  }
  lastField = millis();
  presentation.present(millis());
  if (status != MFRC522::STATUS_OK && status != MFRC522::STATUS_COLLISION) return;

  MFRC522Extended::TagInfo tag{};
  const MFRC522::StatusCode selected = reader.MFRC522::PICC_Select(&tag.uid);
  static MFRC522::StatusCode lastSelected = MFRC522::STATUS_OK;
  if (selected != lastSelected) {
    lastSelected = selected;
    Serial.printf("[nfc] wupa=%u select=%u sak=0x%02X\n", static_cast<unsigned>(status),
                  static_cast<unsigned>(selected), tag.uid.sak);
  }
  if (selected != MFRC522::STATUS_OK) return;

  if ((tag.uid.sak & 0x20) != 0) {
    // Cartao ISO-DEP: primeiro tenta o app HCE; sem prova valida nao publica nada.
    if (reader.PICC_RequestATS(&tag.ats) == MFRC522::STATUS_OK) {
      char token[kHceTokenBytes * 2 + 1] = {};
      const bool read = readHceToken(tag, token, sizeof token);
      reader.TCL_Deselect(&tag);
      reader.PCD_StopCrypto1();
      if (read && hcePublisher != nullptr && presentation.observeToken(token, millis())) {
        if (hcePublisher(token)) {
          Serial.println("[nfc] prova do celular enviada; aguardando decisao");
        } else {
          Serial.println("[nfc] prova do celular indisponivel; reaproxime");
        }
      }
    }
    return;
  }

  char uid[21] = {};
  const bool valid = nfc_scan::formatUid(tag.uid.uidByte, tag.uid.size, uid, sizeof uid);
  reader.PICC_HaltA();
  reader.PCD_StopCrypto1();
  if (!valid || !presentation.observe(uid, millis())) return;
  if (publisher == nullptr || !publisher(uid)) {
    Serial.println("[nfc] tentativa indisponivel; retire e reapresente a tag");
  } else {
    Serial.println("[nfc] tentativa enviada; aguardando decisao do backend");
  }
#endif
}
}  // namespace terminal_nfc
