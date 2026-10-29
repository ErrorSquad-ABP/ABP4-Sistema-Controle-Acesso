-- Outbox dos comandos (DT-13): NULL = intencao gravada na decisao e ainda nao entregue
-- ao broker. O worker republica as pendentes dentro do prazo original.
ALTER TABLE "TerminalCommand" ADD COLUMN "publishedAt" TIMESTAMP(3);
CREATE INDEX "TerminalCommand_publishedAt_expiresAt_idx" ON "TerminalCommand"("publishedAt","expiresAt");

-- Backfill: no deploy, comandos anteriores ainda validos ficariam com "publishedAt" NULL
-- e o relay os republicaria, abrindo de novo o que ja foi entregue ao terminal. Marcar
-- o passado como ja despachado deixa so as intencoes novas na outbox.
UPDATE "TerminalCommand" SET "publishedAt" = "createdAt" WHERE "publishedAt" IS NULL;
