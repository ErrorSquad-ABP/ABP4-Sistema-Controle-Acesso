#pragma once
#include <stdint.h>
#include <string.h>

struct TestReader {
  uint8_t version = 0x92;
  bool present = true;
  bool serialOk = true;
  bool collision = false;
  bool halted = false;
  uint8_t sak = 0x08;
  uint8_t bytes[10] = {0x04, 0xA1, 0xB2, 0xC3};
  uint8_t length = 4;
  int wakeups = 0, halts = 0, stops = 0;
  int initializations = 0;
  int apduCalls = 0;
  bool apduOk = true;
  uint8_t apduReply[40] = {};
  uint8_t apduLength = 0;
};
extern TestReader testReader;

class MFRC522 {
 public:
  enum StatusCode { STATUS_OK, STATUS_TIMEOUT, STATUS_COLLISION, STATUS_ERROR };
  enum PCD_Register { VersionReg };
  struct Uid {
    uint8_t size;
    uint8_t sak;
    uint8_t uidByte[10];
  };
  Uid uid = {};
  MFRC522(int, int) {}
  MFRC522() {}
  void PCD_Init() { ++testReader.initializations; testReader.halted = false; }
  void PCD_SetAntennaGain(uint8_t) {}
  static constexpr uint8_t RxGain_max = 0x07 << 4;
  uint8_t PCD_ReadRegister(PCD_Register) { return testReader.version; }
  bool PICC_IsNewCardPresent() {
    if (!testReader.present) { testReader.halted = false; return false; }
    return !testReader.halted;
  }
  StatusCode PICC_WakeupA(uint8_t*, uint8_t*) {
    ++testReader.wakeups;
    testReader.halted = false;
    if (testReader.collision) return STATUS_COLLISION;
    return testReader.present ? STATUS_OK : STATUS_TIMEOUT;
  }
  StatusCode PICC_Select(Uid* out) {
    if (!testReader.present) return STATUS_TIMEOUT;
    out->size = testReader.length;
    out->sak = testReader.sak;
    memcpy(out->uidByte, testReader.bytes, sizeof out->uidByte);
    return STATUS_OK;
  }
  bool PICC_ReadCardSerial() {
    uid.size = testReader.length;
    uid.sak = testReader.sak;
    memcpy(uid.uidByte, testReader.bytes, sizeof uid.uidByte);
    return testReader.serialOk;
  }
  void PICC_HaltA() { ++testReader.halts; testReader.halted = true; }
  void PCD_StopCrypto1() { ++testReader.stops; }
};
