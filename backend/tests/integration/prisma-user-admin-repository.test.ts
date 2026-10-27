import { randomUUID } from 'node:crypto';
import { describe, expect, it } from 'vitest';
import { createPrismaClient } from '../../src/infrastructure/database/prisma-client.js';
import { PrismaUserAdminRepository } from '../../src/infrastructure/repositories/prisma-user-admin-repository.js';
import { verifyPassword } from '../../src/shared/password-hasher.js';

const connectionString = process.env.DATABASE_URL;
const prisma = connectionString ? createPrismaClient(connectionString) : null;

// Sem banco local o teste e pulado; no CI o Postgres do job + seed sempre existem.
describe.skipIf(!prisma)('PrismaUserAdminRepository', () => {
  it('lista com filtros e busca', async () => {
    const repo = new PrismaUserAdminRepository(prisma!);

    const admins = await repo.list({ page: 1, pageSize: 20, role: 'ADMIN' });
    expect(admins.items.every((user) => user.role === 'ADMIN')).toBe(true);
    expect(admins.items.some((user) => user.email === 'admin@abp4.local')).toBe(true);

    const search = await repo.list({ page: 1, pageSize: 20, search: 'admin@abp4' });
    expect(search.items.map((user) => user.email)).toContain('admin@abp4.local');

    const firstPage = await repo.list({ page: 1, pageSize: 1 });
    expect(firstPage.items).toHaveLength(1);
    expect(firstPage.total).toBeGreaterThan(0);
  });

  it('cria, atualiza e desativa sem perder o cadastro', async () => {
    const repo = new PrismaUserAdminRepository(prisma!);
    const email = `teste-${randomUUID()}@abp4.local`;
    const created = await repo.create({
      name: 'Usuario de Teste',
      email,
      passwordHash: 'scrypt$16384$8$1$salt$hash',
      role: 'VISITOR',
    });

    try {
      expect(created).toMatchObject({ email, role: 'VISITOR', active: true });
      expect(verifyPassword('qualquer', created.passwordHash)).toBe(false);

      const updated = await repo.update(created.id, { name: 'Usuario Editado', active: false });
      expect(updated).toMatchObject({ id: created.id, name: 'Usuario Editado', active: false });

      const found = await repo.findById(created.id);
      expect(found?.active).toBe(false);
      expect(await repo.update('00000000-0000-4000-8000-000000000000', { name: 'X' })).toBeNull();
    } finally {
      await prisma!.user.delete({ where: { id: created.id } });
      await prisma!.$disconnect();
    }
  });
});
