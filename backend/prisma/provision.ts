import { PrismaPg } from "@prisma/adapter-pg";
import { PrismaClient } from "../src/generated/prisma/client.js";
import { parseProvisionConfig } from "../src/shared/seed-guard.js";
import { provisionAdmin } from "./provision-admin.js";

/**
 * Provisionamento real (producao inclusive): so cria o primeiro administrador,
 * com credenciais vindas do ambiente. Nao grava nenhum dado de demonstracao.
 */
async function main(): Promise<void> {
  const config = parseProvisionConfig(process.env);
  const prisma = new PrismaClient({ adapter: new PrismaPg({ connectionString: config.databaseUrl }) });

  try {
    const result = await provisionAdmin(prisma, config);
    console.log(
      result === "created"
        ? `Administrador ${config.adminEmail} criado.`
        : `Administrador ${config.adminEmail} ja existe; nada foi alterado.`,
    );
  } finally {
    await prisma.$disconnect();
  }
}

main().catch((error: unknown) => {
  console.error("Falha no provisionamento:", error instanceof Error ? error.message : error);
  process.exitCode = 1;
});
