CREATE TABLE "ProcessedAccessMessage" (
    "messageId" UUID NOT NULL,
    "processedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "ProcessedAccessMessage_pkey" PRIMARY KEY ("messageId")
);
