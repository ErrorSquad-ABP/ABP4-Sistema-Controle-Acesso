import { describe, expect, it } from 'vitest';
import { GetCurrentUserUseCase } from '../../src/application/auth/get-current-user.use-case.js';
import { LoginUseCase } from '../../src/application/auth/login.use-case.js';
import { UnauthorizedError } from '../../src/domain/errors/domain-error.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { FakeTokenService, InMemoryUserRepository } from '../support/in-memory-repositories.js';

const base: UserRecord = {
  id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  name: 'Admin',
  email: 'admin@abp4.local',
  passwordHash: hashPassword('DemoAdmin123!', 'salt'),
  role: 'ADMIN',
  active: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

function build(overrides: Partial<UserRecord> = {}) {
  const users = new InMemoryUserRepository([{ ...base, ...overrides }]);
  return { users, login: new LoginUseCase(users, new FakeTokenService(users)) };
}

describe('LoginUseCase', () => {
  it('autentica e nao devolve o hash da senha', async () => {
    const { login } = build();

    const out = await login.execute({ email: 'ADMIN@abp4.local', password: 'DemoAdmin123!' });

    expect(out).toMatchObject({ tokenType: 'Bearer', user: { email: 'admin@abp4.local', role: 'ADMIN' } });
    expect(out.expiresIn).toBe(3600);
    expect(JSON.stringify(out)).not.toContain('scrypt$');
  });

  it('senha errada e e-mail inexistente devolvem o mesmo 401', async () => {
    const { login } = build();

    const senhaErrada = await login.execute({ email: 'admin@abp4.local', password: 'errada' }).catch((e: unknown) => e);
    const inexistente = await login.execute({ email: 'ninguem@abp4.local', password: 'errada' }).catch((e: unknown) => e);

    for (const err of [senhaErrada, inexistente]) {
      expect(err).toBeInstanceOf(UnauthorizedError);
      expect((err as Error).message).toBe('Credenciais invalidas');
    }
  });

  it('usuario inativo com senha correta continua 401', async () => {
    const { login } = build({ active: false });

    await expect(login.execute({ email: 'admin@abp4.local', password: 'DemoAdmin123!' })).rejects.toBeInstanceOf(
      UnauthorizedError,
    );
  });
});

describe('GetCurrentUserUseCase', () => {
  it('devolve o usuario do token', async () => {
    const { users } = build();

    await expect(new GetCurrentUserUseCase(users).execute(base.id)).resolves.toMatchObject({
      id: base.id,
      role: 'ADMIN',
    });
  });

  it('usuario desativado depois da emissao -> 401', async () => {
    const { users } = build({ active: false });

    await expect(new GetCurrentUserUseCase(users).execute(base.id)).rejects.toBeInstanceOf(UnauthorizedError);
  });
});
