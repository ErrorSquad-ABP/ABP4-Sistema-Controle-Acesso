#pragma once
#include "MFRC522.h"

class MFRC522Extended : public MFRC522 {
 public:
  struct Ats {
    uint8_t size = 5;
    struct {
      bool supportsCID = true;
    } tc1;
  };
  struct TagInfo {
    Uid uid = {};
    Ats ats = {};
    bool blockNumber = false;
  };
  MFRC522Extended(int ss, int rst) : MFRC522(ss, rst) {}
  StatusCode PICC_RequestATS(Ats* ats) {
    *ats = Ats();
    return STATUS_OK;
  }
  StatusCode TCL_Transceive(TagInfo*, uint8_t*, uint8_t, uint8_t* back, uint8_t* length) {
    ++testReader.apduCalls;
    if (!testReader.apduOk) return STATUS_TIMEOUT;
    if (*length < testReader.apduLength) return STATUS_NO_ROOM;
    memcpy(back, testReader.apduReply, testReader.apduLength);
    *length = testReader.apduLength;
    return STATUS_OK;
  }
  StatusCode TCL_Deselect(TagInfo*) { return STATUS_OK; }
  static constexpr StatusCode STATUS_NO_ROOM = STATUS_ERROR;
};
