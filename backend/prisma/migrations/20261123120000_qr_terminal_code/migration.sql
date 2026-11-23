-- QR compacto: codigo curto, unico e opcional por terminal.
ALTER TABLE "Terminal" ADD COLUMN "qrCode" SMALLINT;

ALTER TABLE "Terminal" ADD CONSTRAINT "Terminal_qrCode_check"
  CHECK ("qrCode" BETWEEN 1 AND 255);

CREATE UNIQUE INDEX "Terminal_qrCode_key" ON "Terminal" ("qrCode");
