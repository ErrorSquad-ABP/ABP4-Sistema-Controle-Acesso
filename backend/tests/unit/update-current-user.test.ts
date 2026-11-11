import { describe, expect, it } from 'vitest';
import { UpdateCurrentUserUseCase } from '../../src/application/auth/update-current-user.use-case.js';
import { UnauthorizedError } from '../../src/domain/errors/domain-error.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { InMemoryUserAdminRepository } from '../support/in-memory-user-admin.js';

const resident: UserRecord = {
  id: '8c9e6679-7425-40de-944b-e07fc1f90ae8',
  name: 'Residente',
  email: 'res@abp4.local',
  passwordHash: hashPassword('DemoAdmin123!', 'salt'),
  role: 'RESIDENT',
  active: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const inactive: UserRecord = { ...resident, id: '9c9e6679-7425-40de-944b-e07fc1f90ae9', active: false };

function build() {
  return new InMemoryUserAdminRepository([resident, inactive]);
}

describe('UpdateCurrentUserUseCase', () => {
  it('muda so o nome e preserva papel, e-mail e id', async () => {
    const users = build();

    const updated = await new UpdateCurrentUserUseCase(users).execute(resident.id, { name: 'Residente Editado' });

    expect(updated).toMatchObject({
      id: resident.id,
      name: 'Residente Editado',
      email: 'res@abp4.local',
      role: 'RESIDENT',
      active: true,
    });
    expect(JSON.stringify(updated)).not.toContain('scrypt$');
  });

  it('usuario desativado ou inexistente -> UnauthorizedError', async () => {
    const useCase = new UpdateCurrentUserUseCase(build());

    await expect(useCase.execute(inactive.id, { name: 'Ninguem' })).rejects.toBeInstanceOf(UnauthorizedError);
    await expect(
      useCase.execute('00000000-0000-4000-8000-000000000000', { name: 'Ninguem' }),
    ).rejects.toBeInstanceOf(UnauthorizedError);
  });
});
