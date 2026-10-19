import { createHash } from "node:crypto";
import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";
import { demoPasswordSalt, hashPassword } from "../src/shared/password-hasher.js";

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error("DATABASE_URL precisa estar configurada para executar a seed.");
}

const adapter = new PrismaPg({ connectionString });
const prisma = new PrismaClient({ adapter });

const demoUsers = {
  admin: {
    id: "a1000000-0000-4000-8000-000000000001",
    name: "Admin Demonstração",
    email: "admin@abp4.local",
    password: "DemoAdmin123!",
    role: "ADMIN" as const,
  },
  member: {
    id: "a1000000-0000-4000-8000-000000000002",
    name: "Usuário Demonstração",
    email: "usuario@abp4.local",
    password: "DemoUser123!",
    role: "RESIDENT" as const,
  },
};

function hashCredential(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}

async function main(): Promise<void> {
  for (const user of Object.values(demoUsers)) {
    const passwordHash = hashPassword(user.password, demoPasswordSalt(user.id));
    await prisma.user.upsert({
      where: { id: user.id },
      update: {
        name: user.name,
        email: user.email,
        passwordHash,
        role: user.role,
        active: true,
      },
      create: {
        id: user.id,
        name: user.name,
        email: user.email,
        passwordHash,
        role: user.role,
      },
    });
  }

  const locationId = "a1000000-0000-4000-8000-000000000003";
  await prisma.accessLocation.upsert({
    where: { id: locationId },
    update: {
      name: "Unidade de Demonstração",
      description: "Local fictício para desenvolvimento e demonstrações.",
      latitude: -23.2237,
      longitude: -45.9009,
      radiusMeters: 100,
      isActive: true,
    },
    create: {
      id: locationId,
      name: "Unidade de Demonstração",
      description: "Local fictício para desenvolvimento e demonstrações.",
      latitude: -23.2237,
      longitude: -45.9009,
      radiusMeters: 100,
    },
  });

  const authorizationId = "a1000000-0000-4000-8000-000000000004";
  await prisma.authorization.upsert({
    where: { id: authorizationId },
    update: {
      userId: demoUsers.member.id,
      locationId,
      createdById: demoUsers.admin.id,
      startsAt: new Date("2026-01-01T00:00:00.000Z"),
      endsAt: new Date("2030-12-31T23:59:59.000Z"),
      maxUses: 20,
      usedCount: 1,
      canceledAt: null,
      cancelReason: null,
    },
    create: {
      id: authorizationId,
      userId: demoUsers.member.id,
      locationId,
      createdById: demoUsers.admin.id,
      startsAt: new Date("2026-01-01T00:00:00.000Z"),
      endsAt: new Date("2030-12-31T23:59:59.000Z"),
      maxUses: 20,
      usedCount: 1,
    },
  });

  const credentialIds = {
    qr: "a1000000-0000-4000-8000-000000000005",
    nfc: "a1000000-0000-4000-8000-000000000006",
  };
  const credentialData = [
    {
      id: credentialIds.qr,
      type: "QR" as const,
      valueHash: hashCredential("abp4-demo-qr-credential"),
      validUntil: new Date("2030-12-31T23:59:59.000Z"),
    },
    {
      id: credentialIds.nfc,
      type: "NFC" as const,
      valueHash: hashCredential("ABP4-DEMO-NFC-UID"),
      validUntil: null,
    },
  ];

  for (const credential of credentialData) {
    await prisma.credential.upsert({
      where: { id: credential.id },
      update: {
        userId: demoUsers.member.id,
        type: credential.type,
        valueHash: credential.valueHash,
        validFrom: new Date("2026-01-01T00:00:00.000Z"),
        validUntil: credential.validUntil,
        revokedAt: null,
      },
      create: {
        ...credential,
        userId: demoUsers.member.id,
        validFrom: new Date("2026-01-01T00:00:00.000Z"),
      },
    });
  }

  await prisma.accessEvent.upsert({
    where: { id: "a1000000-0000-4000-8000-000000000007" },
    update: {
      userId: demoUsers.member.id,
      authorizationId,
      credentialId: credentialIds.qr,
      locationId,
      method: "QR",
      decision: "GRANTED",
      reason: null,
      latitude: -23.2237,
      longitude: -45.9009,
      distanceMeters: 0,
      // Data fixa: rodar a seed de novo nao muda o historico.
      occurredAt: new Date("2026-10-19T12:00:00.000Z"),
    },
    create: {
      id: "a1000000-0000-4000-8000-000000000007",
      userId: demoUsers.member.id,
      authorizationId,
      credentialId: credentialIds.qr,
      locationId,
      method: "QR",
      decision: "GRANTED",
      latitude: -23.2237,
      longitude: -45.9009,
      distanceMeters: 0,
      occurredAt: new Date("2026-10-19T12:00:00.000Z"),
    },
  });

  const counts = await Promise.all([
    prisma.user.count(),
    prisma.accessLocation.count(),
    prisma.authorization.count(),
    prisma.credential.count(),
    prisma.accessEvent.count(),
  ]);
  console.log(
    `Seed concluída. Registros: ${counts[0]} usuários, ${counts[1]} locais, ${counts[2]} autorizações, ${counts[3]} credenciais e ${counts[4]} eventos.`,
  );
  console.log("Contas de demonstração: admin@abp4.local / DemoAdmin123! e usuario@abp4.local / DemoUser123!.");
}

main()
  .catch((error: unknown) => {
    console.error("Falha ao executar a seed:", error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
