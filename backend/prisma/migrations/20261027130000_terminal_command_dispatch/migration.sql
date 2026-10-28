-- Outbox dos comandos (DT-13): NULL = intencao gravada na decisao e ainda nao entregue
-- ao broker. O worker republica as pendentes dentro do prazo original.
ALTER TABLE "TerminalCommand" ADD COLUMN "publishedAt" TIMESTAMP(3);
CREATE INDEX "TerminalCommand_publishedAt_expiresAt_idx" ON "TerminalCommand"("publishedAt","expiresAt");
