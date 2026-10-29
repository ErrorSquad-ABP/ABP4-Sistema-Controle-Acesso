-- DT-15: o expurgo diario apaga marcas com mais de 24 h em lotes ordenados por processedAt.
CREATE INDEX "ProcessedAccessMessage_processedAt_idx" ON "ProcessedAccessMessage"("processedAt");
