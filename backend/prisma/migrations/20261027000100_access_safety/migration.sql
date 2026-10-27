CREATE TABLE "Terminal" (
  "id" TEXT PRIMARY KEY CHECK ("id" ~ '^[a-z0-9][a-z0-9-]{0,63}$'),
  "locationId" UUID NOT NULL REFERENCES "AccessLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "Terminal_locationId_idx" ON "Terminal"("locationId");

ALTER TABLE "AccessEvent" ADD COLUMN "terminalId" TEXT;
-- Distancias terrestres podem chegar a ~20 mil km; negativas distantes tambem sao auditadas.
ALTER TABLE "AccessEvent" ALTER COLUMN "distanceMeters" TYPE DECIMAL(10,2);
CREATE INDEX "AccessEvent_terminalId_occurredAt_idx" ON "AccessEvent"("terminalId","occurredAt");

CREATE TABLE "TerminalCommand" (
  "commandId" UUID PRIMARY KEY,
  "requestId" UUID NOT NULL UNIQUE,
  "terminalId" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "ackMessageId" UUID,
  "ackStatus" TEXT CHECK ("ackStatus" IN ('executed','rejected','expired')),
  "ackReason" TEXT,
  "acknowledgedAt" TIMESTAMP(3)
);
CREATE INDEX "TerminalCommand_terminalId_createdAt_idx" ON "TerminalCommand"("terminalId","createdAt");
CREATE INDEX "TerminalCommand_expiresAt_idx" ON "TerminalCommand"("expiresAt");

CREATE TABLE "TerminalQrToken" (
  "valueHash" TEXT PRIMARY KEY,
  "terminalId" TEXT NOT NULL REFERENCES "Terminal"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  "expiresAt" TIMESTAMP(3) NOT NULL
);
CREATE INDEX "TerminalQrToken_expiresAt_idx" ON "TerminalQrToken"("expiresAt");
