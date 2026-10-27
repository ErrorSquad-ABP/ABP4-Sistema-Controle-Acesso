import { describe, expect, it } from 'vitest';
import { createPrismaClient } from '../../src/infrastructure/database/prisma-client.js';
import { PrismaAccessEventRepository } from '../../src/infrastructure/repositories/prisma-access-event-repository.js';

const connectionString = process.env.DATABASE_URL;
const prisma = connectionString ? createPrismaClient(connectionString) : null;

describe.skipIf(!prisma)('PrismaAccessEventRepository', () => {
  it('lista o evento da seed com usuario e local', async () => {
    const repo = new PrismaAccessEventRepository(prisma!);

    const page = await repo.list({ page: 1, pageSize: 20 });

    expect(page.total).toBeGreaterThan(0);
    const event = page.items[0];
    expect(event?.location.name).toBe('Unidade de Demonstração');
    expect(event?.user?.role).toBe('RESIDENT');
    expect(event?.occurredAt).toMatch(/Z$/);
    await prisma!.$disconnect();
  });
});
