#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "nfc_scan.h"

int main() {
  char uid[21];
  const uint8_t bytes[] = {0x00, 0xA1, 0xB2, 0x03, 0xFF, 0x04, 0xAB, 0xCD, 0xEF, 0x12};
  assert(nfc_scan::formatUid(bytes, 4, uid, sizeof uid));
  assert(strcmp(uid, "00A1B203") == 0);
  assert(nfc_scan::formatUid(bytes, 7, uid, sizeof uid));
  assert(strcmp(uid, "00A1B203FF04AB") == 0);
  assert(nfc_scan::formatUid(bytes, 10, uid, sizeof uid));
  assert(strcmp(uid, "00A1B203FF04ABCDEF12") == 0);
  assert(!nfc_scan::formatUid(bytes, 3, uid, sizeof uid));
  assert(!nfc_scan::formatUid(bytes, 4, uid, 8));
  assert(!nfc_scan::formatUid(nullptr, 4, uid, sizeof uid));
  assert(!nfc_scan::validUid("00a1b203"));
  assert(!nfc_scan::validUid("ZZ001122"));
  assert(!nfc_scan::validUid(""));

  nfc_scan::Presentation presentation;
  assert(presentation.observe("00A1B203", 0));
  for (uint32_t now = 100; now <= 10000; now += 100) {
    assert(!presentation.observe("00A1B203", now));
  }
  // Falha de RF breve nao rearma a tag; presenca sem UID tambem nao.
  presentation.absent(10499, 500);
  assert(!presentation.observe("00A1B203", 10500));
  presentation.present(10900);
  presentation.absent(11399, 500);
  assert(!presentation.observe("00A1B203", 11400));
  presentation.absent(11900, 500);
  assert(presentation.observe("00A1B203", 12000));
  assert(presentation.observe("11223344", 12100));
  assert(!presentation.observe("11223344", 12200));
  assert(!presentation.observe("bad", 12300));

  nfc_scan::Presentation rollover;
  assert(rollover.observe("11223344", UINT32_MAX - 100));
  rollover.absent(399, 500);
  assert(rollover.observe("11223344", 400));
  puts("nfc: UID, apresentacao unica, remocao e rollover OK");
}
