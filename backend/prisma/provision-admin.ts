import { randomUUID } from "node:crypto";
import { hashPassword, newPasswordSalt } from "../src/shared/password-hasher.js";
import type { ProvisionConfig } from "../src/shared/seed-guard.js";

/** Parte do Prisma Client que o provisionamento usa; permite testar sem banco. */
export interface ProvisionDb {
  user: {
    findUnique(args: { where: { email: string } }): Promise<{ id: string } | null>;
    create(args: {
      data: { id: string; name: string; email: string; passwordHash: string; role: "ADMIN" };
    }): Promise<unknown>;
  };
}

export type ProvisionResult = "created" | "already-exists";

/**
 * Cria o primeiro administrador. Idempotente e nao destrutiva: se o e-mail ja
 * existe, nao troca senha, nome, papel nem reativa a conta.
 */
export async function provisionAdmin(
  db: ProvisionDb,
  config: Pick<ProvisionConfig, "adminName" | "adminEmail" | "adminPassword">,
): Promise<ProvisionResult> {
  const existing = await db.user.findUnique({ where: { email: config.adminEmail } });
  if (existing) {
    return "already-exists";
  }

  await db.user.create({
    data: {
      id: randomUUID(),
      name: config.adminName,
      email: config.adminEmail,
      passwordHash: hashPassword(config.adminPassword, newPasswordSalt()),
      role: "ADMIN",
    },
  });
  return "created";
}
