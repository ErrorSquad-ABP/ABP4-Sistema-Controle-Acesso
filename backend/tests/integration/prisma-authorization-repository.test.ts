import { describe, expect, it } from 'vitest';
import { createPrismaClient } from '../../src/infrastructure/database/prisma-client.js';
import { PrismaAuthorizationRepository } from '../../src/infrastructure/repositories/prisma-authorization-repository.js';

const connectionString = process.env.DATABASE_URL;
const prisma = connectionString ? createPrismaClient(connectionString) : null;

const memberId = 'a1000000-0000-4000-8000-000000000002';
const seedAuthorizationId = 'a1000000-0000-4000-8000-000000000004';

// Sem banco local o teste e pulado; no CI o Postgres do job + seed sempre existem.
describe.skipIf(!prisma)('PrismaAuthorizationRepository', () => {
  it('lista as autorizacoes do usuario com status calculado', async () => {
    const repo = new PrismaAuthorizationRepository(prisma!);

    const page = await repo.listForUser({ userId: memberId, page: 1, pageSize: 20, now: new Date() });
    const seed = page.items.find((item) => item.id === seedAuthorizationId);

    expect(page.total).toBeGreaterThan(0);
    expect(seed).toMatchObject({
      status: 'ACTIVE',
      user: { role: 'RESIDENT' },
      location: { name: 'Unidade de Demonstração' },
    });
    expect(seed?.remainingUses).toBe((seed?.maxUses ?? 0) - (seed?.usedCount ?? 0));
    expect(seed?.startsAt).toMatch(/Z$/);
    expect(seed?.endsAt).toMatch(/Z$/);
    await prisma!.$disconnect();
  });

  it('filtra pela situacao calculada sem misturar usuarios', async () => {
    const repo = new PrismaAuthorizationRepository(prisma!);

    const expired = await repo.listForUser({
      userId: memberId,
      page: 1,
      pageSize: 20,
      status: 'EXPIRED',
      now: new Date(),
    });
    expect(expired.items.every((item) => item.status === 'EXPIRED')).toBe(true);

    const anotherUser = await repo.listForUser({
      userId: 'a1000000-0000-4000-8000-000000000001',
      page: 1,
      pageSize: 20,
      now: new Date(),
    });
    expect(anotherUser.items.some((item) => item.id === seedAuthorizationId)).toBe(false);
    await prisma!.$disconnect();
  });
});
