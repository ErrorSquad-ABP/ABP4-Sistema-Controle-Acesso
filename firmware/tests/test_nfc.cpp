#include <assert.h>
#include <stdio.h>
#include <string.h>
#include "Arduino.h"
#include "MFRC522.h"
#include "SPI.h"
#include "modules/nfc.h"

uint32_t testNow = 0;
TestSerial Serial;
TestSPI SPI;
TestReader testReader;
int publishes = 0;
bool online = true;
bool publish(const char* uid) {
  assert(strcmp(uid, "04A1B2C3") == 0);
  ++publishes;
  return online;
}
void tick(uint32_t now) { testNow = now; terminal_nfc::update(); }

int main(int argc, char**) {
  if (argc > 1) testReader.version = 0xFF;
  terminal_nfc::setPublisher(publish);
  terminal_nfc::begin();
  assert(SPI.sck == 18 && SPI.miso == 19 && SPI.mosi == 23 && SPI.ss == 32);
  if (argc > 1) {
    tick(0); tick(1000);
    assert(testReader.wakeups == 0 && publishes == 0);
    puts("nfc: leitor ausente fail-closed OK");
    return 0;
  }
  tick(0);
  assert(publishes == 1);
  assert(testReader.halts == 1 && testReader.stops == 1);
  tick(50);
  assert(testReader.wakeups == 1);
  tick(100); tick(200);
  assert(publishes == 1);  // WUPA da mesma tag em HALT nao reenvia.
  testReader.present = false;
  tick(300); tick(400);
  testReader.present = true;
  tick(500);
  assert(publishes == 1);
  testReader.present = false;
  tick(600); tick(1000);
  testReader.present = true;
  online = false;
  tick(1100);
  assert(publishes == 2);
  online = true;
  tick(1200); tick(2000);
  assert(publishes == 2);  // Recuperar rede nao reenvia tag mantida no leitor.
  testReader.serialOk = false;
  testReader.collision = true;
  tick(3000);
  testReader.collision = false;
  testReader.serialOk = true;
  tick(3100);
  assert(publishes == 2);
  testReader.length = 3;
  tick(3200);
  assert(publishes == 2);
  assert(testReader.halts == testReader.stops);
  puts("nfc: polling real, HALT, ausencia, colisao e falha de envio OK");
}
