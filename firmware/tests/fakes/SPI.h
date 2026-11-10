#pragma once
struct TestSPI {
  int sck = -1, miso = -1, mosi = -1, ss = -1;
  void begin(int a, int b, int c, int d) { sck = a; miso = b; mosi = c; ss = d; }
};
extern TestSPI SPI;
