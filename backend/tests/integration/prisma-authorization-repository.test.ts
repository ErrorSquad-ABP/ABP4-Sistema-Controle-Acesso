import { randomUUID } from 'node:crypto';
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

  it('traduz os quatro estados no where e pagina no banco', async () => {
    const now = new Date();
    const day = 86_400_000;
    const base = {
      userId: memberId,
      locationId: 'a1000000-0000-4000-8000-000000000003',
      createdById: 'a1000000-0000-4000-8000-000000000001',
      maxUses: 5,
    };
    const ids = {
      CANCELED: randomUUID(),
      SCHEDULED: randomUUID(),
      EXPIRED: randomUUID(),
      ACTIVE: randomUUID(),
    };

    await prisma!.authorization.createMany({
      data: [
        { ...base, id: ids.CANCELED, startsAt: now, endsAt: new Date(now.getTime() + day), usedCount: 0, canceledAt: now },
        { ...base, id: ids.SCHEDULED, startsAt: new Date(now.getTime() + day), endsAt: new Date(now.getTime() + 2 * day), usedCount: 0 },
        { ...base, id: ids.EXPIRED, startsAt: new Date(now.getTime() - 2 * day), endsAt: new Date(now.getTime() - day), usedCount: 0 },
        { ...base, id: ids.ACTIVE, startsAt: new Date(now.getTime() - day), endsAt: new Date(now.getTime() + day), usedCount: 0 },
      ],
    });

    try {
      const repo = new PrismaAuthorizationRepository(prisma!);
      for (const [status, id] of Object.entries(ids)) {
        const page = await repo.listForUser({
          userId: memberId,
          status: status as 'CANCELED' | 'SCHEDULED' | 'EXPIRED' | 'ACTIVE',
          page: 1,
          pageSize: 100,
          now,
        });
        const created = page.items.filter((item) => (Object.values(ids) as string[]).includes(item.id));
        expect(created.map((item) => item.id), status).toEqual([id]);
        expect(created[0]?.status, status).toBe(status);
      }

      const firstPage = await repo.listForUser({ userId: memberId, page: 1, pageSize: 1, now });
      expect(firstPage.items).toHaveLength(1);
      expect(firstPage.total).toBeGreaterThan(1);
    } finally {
      await prisma!.authorization.deleteMany({ where: { id: { in: Object.values(ids) } } });
    }

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
