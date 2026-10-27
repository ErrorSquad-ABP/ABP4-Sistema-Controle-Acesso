import { describe, expect, it } from 'vitest';
import { createPrismaClient } from '../../src/infrastructure/database/prisma-client.js';
import { PrismaUserRepository } from '../../src/infrastructure/repositories/prisma-user-repository.js';

const connectionString = process.env.DATABASE_URL;
const prisma = connectionString ? createPrismaClient(connectionString) : null;

// Sem banco local o teste e pulado; no CI o Postgres do job + seed sempre existem.
describe.skipIf(!prisma)('PrismaUserRepository', () => {
  it('encontra o admin da seed por e-mail normalizado', async () => {
    const repo = new PrismaUserRepository(prisma!);
    const user = await repo.findByEmail('ADMIN@abp4.local');

    expect(user?.role).toBe('ADMIN');
    expect(user?.passwordHash.startsWith('scrypt$')).toBe(true);
    await prisma!.$disconnect();
  });
});
