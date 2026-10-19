-- CreateEnum
CREATE TYPE "UserRole" AS ENUM ('USER', 'ADMIN');

-- CreateEnum
CREATE TYPE "AuthorizationStatus" AS ENUM ('ACTIVE', 'CANCELLED');

-- CreateEnum
CREATE TYPE "CredentialType" AS ENUM ('QR', 'NFC');

-- CreateEnum
CREATE TYPE "AccessMethod" AS ENUM ('QR', 'NFC');

-- CreateEnum
CREATE TYPE "AccessDecision" AS ENUM ('ALLOWED', 'DENIED');

-- CreateTable
CREATE TABLE "User" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "email" TEXT NOT NULL,
    "passwordHash" TEXT NOT NULL,
    "role" "UserRole" NOT NULL DEFAULT 'USER',
    "isActive" BOOLEAN NOT NULL DEFAULT true,
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
    "accessLocationId" UUID NOT NULL,
    "createdById" UUID,
    "status" "AuthorizationStatus" NOT NULL DEFAULT 'ACTIVE',
    "validFrom" TIMESTAMP(3) NOT NULL,
    "validUntil" TIMESTAMP(3) NOT NULL,
    "maxUses" INTEGER,
    "usesCount" INTEGER NOT NULL DEFAULT 0,
    "cancelledAt" TIMESTAMP(3),
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
    "accessLocationId" UUID,
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
CREATE INDEX "User_role_isActive_idx" ON "User"("role", "isActive");

-- CreateIndex
CREATE INDEX "AccessLocation_isActive_idx" ON "AccessLocation"("isActive");

-- CreateIndex
CREATE INDEX "Authorization_userId_status_validFrom_validUntil_idx" ON "Authorization"("userId", "status", "validFrom", "validUntil");

-- CreateIndex
CREATE INDEX "Authorization_accessLocationId_status_idx" ON "Authorization"("accessLocationId", "status");

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
CREATE INDEX "AccessEvent_accessLocationId_occurredAt_idx" ON "AccessEvent"("accessLocationId", "occurredAt");

-- CreateIndex
CREATE INDEX "AccessEvent_authorizationId_idx" ON "AccessEvent"("authorizationId");

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Authorization" ADD CONSTRAINT "Authorization_accessLocationId_fkey" FOREIGN KEY ("accessLocationId") REFERENCES "AccessLocation"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Credential" ADD CONSTRAINT "Credential_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_authorizationId_fkey" FOREIGN KEY ("authorizationId") REFERENCES "Authorization"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_credentialId_fkey" FOREIGN KEY ("credentialId") REFERENCES "Credential"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "AccessEvent" ADD CONSTRAINT "AccessEvent_accessLocationId_fkey" FOREIGN KEY ("accessLocationId") REFERENCES "AccessLocation"("id") ON DELETE SET NULL ON UPDATE CASCADE;
