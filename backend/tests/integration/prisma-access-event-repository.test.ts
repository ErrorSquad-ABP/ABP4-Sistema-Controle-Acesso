import { describe, expect, it } from 'vitest';
import { createPrismaClient } from '../../src/infrastructure/database/prisma-client.js';
import { PrismaAccessEventRepository } from '../../src/infrastructure/repositories/prisma-access-event-repository.js';

const connectionString = process.env.DATABASE_URL;
const prisma = connectionString ? createPrismaClient(connectionString) : null;

const seedLocationId = 'a1000000-0000-4000-8000-000000000003';

describe.skipIf(!prisma)('PrismaAccessEventRepository', () => {
  it('lista o evento da seed com usuario e local', async () => {
    const repo = new PrismaAccessEventRepository(prisma!);

    const page = await repo.list({ page: 1, pageSize: 20 });

    expect(page.total).toBeGreaterThan(0);
    // Outros testes da mesma suite gravam eventos recentes: localize o da seed.
    const event = page.items.find((item) => item.location?.id === seedLocationId);
    expect(event?.location?.name).toBe('Unidade de Demonstração');
    expect(event?.user?.role).toBe('RESIDENT');
    expect(event?.occurredAt).toMatch(/Z$/);
    await prisma!.$disconnect();
  });
});
