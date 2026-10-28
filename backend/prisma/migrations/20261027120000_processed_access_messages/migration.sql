-- Deduplicacao duravel: uma linha por messageId processado, sem TTL por enquanto.
-- Crescimento linear ao volume de tentativas; acompanhar tamanho e definir expurgo
-- por processedAt quando houver volume, preservando a idempotencia das mensagens em transito.
CREATE TABLE "ProcessedAccessMessage" (
    "messageId" UUID NOT NULL,
    "processedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ProcessedAccessMessage_pkey" PRIMARY KEY ("messageId")
);
