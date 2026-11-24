-- Prova efemera do NFC do celular (HCE), de uso unico.
ALTER TYPE "CredentialType" ADD VALUE IF NOT EXISTS 'NFC_HCE';

ALTER TABLE "Credential" ADD COLUMN "consumedAt" TIMESTAMP(3);
