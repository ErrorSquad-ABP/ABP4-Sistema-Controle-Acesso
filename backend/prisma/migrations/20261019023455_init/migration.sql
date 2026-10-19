-- CreateSchema
CREATE SCHEMA IF NOT EXISTS "public";

-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('ADMIN', 'RESIDENT', 'VISITOR');

-- CreateEnum
CREATE TYPE "CredentialType" AS ENUM ('QR', 'NFC');

-- CreateEnum
CREATE TYPE "AccessMethod" AS ENUM ('QR', 'NFC');

-- CreateEnum
CREATE TYPE "AccessDecision" AS ENUM ('GRANTED', 'DENIED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL,
    "active" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccessLocation" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "latitude" DECIMAL(9,6) NOT NULL,
    "longitude" DECIMAL(9,6) NOT NULL,
    "radiusMeters" INTEGER NOT NULL DEFAULT 100,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "AccessLocation_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Authorization" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "locationId" UUID NOT NULL,
    "createdById" UUID,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "maxUses" INTEGER NOT NULL,
    "usedCount" INTEGER NOT NULL DEFAULT 0,
    "canceledAt" TIMESTAMP(3),
    "cancelReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Authorization_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "Credential" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "type" "CredentialType" NOT NULL,
    "valueHash" TEXT NOT NULL,
    "validFrom" TIMESTAMP(3),
    "validUntil" TIMESTAMP(3),
    "revokedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "Credential_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "AccessEvent" (
    "id" UUID NOT NULL,
    "userId" UUID,
    "authorizationId" UUID,
    "credentialId" UUID,
    "locationId" UUID,
    "method" "AccessMethod" NOT NULL,
    "decision" "AccessDecision" NOT NULL,
    "reason" TEXT,
    "latitude" DECIMAL(9,6),
    "longitude" DECIMAL(9,6),
    "distanceMeters" DECIMAL(8,2),
    "occurredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "AccessEvent_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

-- CreateIndex
CREATE INDEX "User_role_active_idx" ON "User"("role", "active");

-- CreateIndex
CREATE INDEX "AccessLocation_isActive_idx" ON "AccessLocation"("isActive");

-- CreateIndex
CREATE INDEX "Authorization_userId_startsAt_endsAt_idx" ON "Authorization"("userId", "startsAt", "endsAt");

-- CreateIndex
CREATE INDEX "Authorization_locationId_idx" ON "Authorization"("locationId");

-- CreateIndex
CREATE INDEX "Authorization_createdById_idx" ON "Authorization"("createdById");

-- CreateIndex
CREATE UNIQUE INDEX "Credential_valueHash_key" ON "Credential"("valueHash");

-- CreateIndex
CREATE INDEX "Credential_userId_type_revokedAt_idx" ON "Credential"("userId", "type", "revokedAt");

-- CreateIndex
CREATE INDEX "Credential_validUntil_idx" ON "Credential"("validUntil");

-- CreateIndex
CREATE INDEX "AccessEvent_occurredAt_idx" ON "AccessEvent"("occurredAt");

-- CreateIndex
CREATE INDEX "AccessEvent_userId_occurredAt_idx" ON "AccessEvent"("userId", "occurredAt");

-- CreateIndex
CREATE INDEX "AccessEvent_locationId_occurredAt_idx" ON "AccessEvent"("locationId", "occurredAt");

-- CreateIndex
CREATE INDEX "AccessEvent_authorizationId_idx" ON "AccessEvent"("authorizationId");

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "AccessLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Credential" ADD CONSTRAINT "Credential_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_authorizationId_fkey" FOREIGN KEY ("authorizationId") REFERENCES "Authorization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_credentialId_fkey" FOREIGN KEY ("credentialId") REFERENCES "Credential"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_locationId_fkey" FOREIGN KEY ("locationId") REFERENCES "AccessLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;

