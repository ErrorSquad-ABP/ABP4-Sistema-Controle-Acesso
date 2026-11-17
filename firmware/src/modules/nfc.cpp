#include "nfc.h"

#include <Arduino.h>
#include <MFRC522.h>
#include <SPI.h>

#include "nfc_scan.h"
#include "retry_interval.h"
#include "terminal_settings.h"

namespace {
terminal_nfc::Publisher publisher = nullptr;
#if NFC_ENABLED
MFRC522 reader(NFC_SS_PIN, NFC_RST_PIN);
RetryInterval poll(NFC_POLL_MS);
nfc_scan::Presentation presentation;
bool available = false;
#endif
}

namespace terminal_nfc {
void setPublisher(Publisher value) { publisher = value; }

void begin() {
#if NFC_ENABLED
  SPI.begin(NFC_SCK_PIN, NFC_MISO_PIN, NFC_MOSI_PIN, NFC_SS_PIN);
  reader.PCD_Init();
  const uint8_t version = reader.PCD_ReadRegister(MFRC522::VersionReg);
  available = version != 0 && version != 0xFF;
  Serial.println(available ? "[nfc] RC522 pronto" : "[nfc] RC522 indisponivel; confira SPI/alimentacao");
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
    if (responding != available) {
      available = responding;
      Serial.println(responding ? "[nfc] RC522 voltou a responder"
                                : "[nfc] RC522 parou de responder (SPI/energia)");
    }
  }
  if (!available || !poll.ready(millis())) return;
  uint8_t atqa[2];
  uint8_t size = sizeof atqa;
  const MFRC522::StatusCode status = reader.PICC_WakeupA(atqa, &size);
  if (status == MFRC522::STATUS_TIMEOUT) {
    presentation.absent(millis(), NFC_REMOVAL_MS);
    return;
  }
  presentation.present(millis());
  if (status != MFRC522::STATUS_OK && status != MFRC522::STATUS_COLLISION) return;
  if (!reader.PICC_ReadCardSerial()) return;
  char uid[21];
  const bool valid = nfc_scan::formatUid(reader.uid.uidByte, reader.uid.size, uid, sizeof uid);
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
}
