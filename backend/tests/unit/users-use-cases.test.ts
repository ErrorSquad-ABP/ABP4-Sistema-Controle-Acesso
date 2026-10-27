import { describe, expect, it } from 'vitest';
import { CreateUserUseCase } from '../../src/application/users/create-user.use-case.js';
import { DeleteUserUseCase } from '../../src/application/users/delete-user.use-case.js';
import { GetUserUseCase } from '../../src/application/users/get-user.use-case.js';
import { ListUsersUseCase } from '../../src/application/users/list-users.use-case.js';
import { UpdateUserUseCase } from '../../src/application/users/update-user.use-case.js';
import { ConflictError, NotFoundError } from '../../src/domain/errors/domain-error.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { hashPassword, verifyPassword } from '../../src/shared/password-hasher.js';
import { escapeLikePattern } from '../../src/infrastructure/repositories/prisma-user-admin-repository.js';
import { InMemoryUserAdminRepository } from '../support/in-memory-user-admin.js';

const admin: UserRecord = {
  id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  name: 'Admin',
  email: 'admin@abp4.local',
  passwordHash: hashPassword('DemoAdmin123!', 'salt'),
  role: 'ADMIN',
  active: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const resident: UserRecord = {
  ...admin,
  id: '8c9e6679-7425-40de-944b-e07fc1f90ae8',
  name: 'Residente',
  email: 'res@abp4.local',
  role: 'RESIDENT',
};

const visitor: UserRecord = {
  ...admin,
  id: '9c9e6679-7425-40de-944b-e07fc1f90ae9',
  name: 'Visitante',
  email: 'vis@abp4.local',
  role: 'VISITOR',
  active: false,
};

function build() {
  return new InMemoryUserAdminRepository([admin, resident, visitor]);
}

describe('CreateUserUseCase', () => {
  it('cria com hash scrypt de salt novo e nao vaza a senha', async () => {
    const users = build();

    const created = await new CreateUserUseCase(users).execute({
      name: 'Maria Souza',
      email: 'Maria.Souza@Exemplo.com',
      password: 'senha-forte-123',
      role: 'VISITOR',
    });

    expect(created).toMatchObject({ name: 'Maria Souza', email: 'maria.souza@exemplo.com', role: 'VISITOR', active: true });
    expect(JSON.stringify(created)).not.toContain('scrypt$');
    expect(JSON.stringify(created)).not.toContain('senha-forte-123');

    const stored = await users.findByEmail('maria.souza@exemplo.com');
    expect(stored?.passwordHash.startsWith('scrypt$')).toBe(true);
    expect(verifyPassword('senha-forte-123', stored!.passwordHash)).toBe(true);
  });

  it('gera salts diferentes para a mesma senha', async () => {
    const users = build();
    const create = new CreateUserUseCase(users);

    await create.execute({ name: 'Ana', email: 'ana@abp4.local', password: 'senha-forte-123', role: 'RESIDENT' });
    await create.execute({ name: 'Bia', email: 'bia@abp4.local', password: 'senha-forte-123', role: 'RESIDENT' });

    const ana = await users.findByEmail('ana@abp4.local');
    const bia = await users.findByEmail('bia@abp4.local');
    expect(ana?.passwordHash).not.toBe(bia?.passwordHash);
  });

  it('e-mail duplicado (caixa diferente) -> 409', async () => {
    await expect(
      new CreateUserUseCase(build()).execute({
        name: 'Outro Admin',
        email: 'ADMIN@abp4.local',
        password: 'senha-forte-123',
        role: 'VISITOR',
      }),
    ).rejects.toBeInstanceOf(ConflictError);
  });
});

describe('ListUsersUseCase', () => {
  it('filtra por perfil, ativo e busca por nome/e-mail', async () => {
    const list = new ListUsersUseCase(build());

    expect((await list.execute({ page: 1, pageSize: 20 })).total).toBe(3);
    expect((await list.execute({ page: 1, pageSize: 20, role: 'VISITOR' })).items.map((u) => u.email)).toEqual([
      'vis@abp4.local',
    ]);
    expect((await list.execute({ page: 1, pageSize: 20, active: true })).total).toBe(2);
    expect((await list.execute({ page: 1, pageSize: 20, search: 'RES' })).items.map((u) => u.email)).toEqual([
      'res@abp4.local',
    ]);
    expect((await list.execute({ page: 1, pageSize: 20, search: 'abp4' })).total).toBe(3);
  });

  it('pagina e devolve o total do filtro sem o hash', async () => {
    const page = await new ListUsersUseCase(build()).execute({ page: 2, pageSize: 2 });

    expect(page).toMatchObject({ page: 2, pageSize: 2, total: 3 });
    expect(page.items).toHaveLength(1);
    expect(JSON.stringify(page)).not.toContain('scrypt$');
  });
});

describe('GetUserUseCase', () => {
  it('devolve o usuario sem hash', async () => {
    const user = await new GetUserUseCase(build()).execute(resident.id);
    expect(user).toMatchObject({ id: resident.id, email: 'res@abp4.local' });
    expect(JSON.stringify(user)).not.toContain('scrypt$');
  });

  it('id desconhecido -> 404', async () => {
    await expect(new GetUserUseCase(build()).execute('00000000-0000-4000-8000-000000000000')).rejects.toBeInstanceOf(
      NotFoundError,
    );
  });
});

describe('ultimo administrador', () => {
  it('nao deixa desativar, rebaixar ou excluir o unico ADMIN ativo', async () => {
    const users = new InMemoryUserAdminRepository([admin]);

    await expect(new DeleteUserUseCase(users).execute(admin.id)).rejects.toBeInstanceOf(ConflictError);
    await expect(
      new UpdateUserUseCase(users).execute(admin.id, { role: 'RESIDENT' }),
    ).rejects.toBeInstanceOf(ConflictError);
    await expect(
      new UpdateUserUseCase(users).execute(admin.id, { active: false }),
    ).rejects.toBeInstanceOf(ConflictError);
  });

  it('permite quando existe outro ADMIN ativo', async () => {
    const outroAdmin: UserRecord = {
      ...admin,
      id: 'ac9e6679-7425-40de-944b-e07fc1f90aea',
      email: 'admin2@abp4.local',
    };
    const users = new InMemoryUserAdminRepository([admin, outroAdmin]);

    await expect(new DeleteUserUseCase(users).execute(admin.id)).resolves.toBeUndefined();
  });
});

describe('busca literal', () => {
  it('escapa curingas do LIKE', () => {
    expect(escapeLikePattern('100%_a\\b')).toBe('100\\%\\_a\\\\b');
  });
});

describe('UpdateUserUseCase', () => {
  it('atualiza so os campos enviados', async () => {
    const users = build();

    const updated = await new UpdateUserUseCase(users).execute(resident.id, { name: 'Residente Editado' });

    expect(updated).toMatchObject({ id: resident.id, name: 'Residente Editado', role: 'RESIDENT', active: true });
    expect((await users.findById(resident.id))?.email).toBe('res@abp4.local');
  });

  it('troca a senha com hash novo', async () => {
    const users = build();

    await new UpdateUserUseCase(users).execute(resident.id, { password: 'outra-senha-123' });

    const stored = await users.findById(resident.id);
    expect(verifyPassword('outra-senha-123', stored!.passwordHash)).toBe(true);
    expect(verifyPassword('DemoAdmin123!', stored!.passwordHash)).toBe(false);
  });

  it('aceita o proprio e-mail normalizado e rejeita o de outro usuario', async () => {
    const users = build();
    const update = new UpdateUserUseCase(users);

    await expect(update.execute(resident.id, { email: 'RES@abp4.local' })).resolves.toMatchObject({
      email: 'res@abp4.local',
    });
    await expect(update.execute(resident.id, { email: 'admin@abp4.local' })).rejects.toBeInstanceOf(ConflictError);
  });

  it('desativar pelo PATCH', async () => {
    const updated = await new UpdateUserUseCase(build()).execute(resident.id, { active: false });
    expect(updated.active).toBe(false);
  });

  it('id desconhecido -> 404', async () => {
    await expect(
      new UpdateUserUseCase(build()).execute('00000000-0000-4000-8000-000000000000', { name: 'X Y' }),
    ).rejects.toBeInstanceOf(NotFoundError);
  });
});

describe('DeleteUserUseCase', () => {
  it('faz exclusao logica, preservando o cadastro', async () => {
    const users = build();

    await new DeleteUserUseCase(users).execute(resident.id);

    const stored = await users.findById(resident.id);
    expect(stored).toMatchObject({ id: resident.id, active: false });
  });

  it('id desconhecido -> 404', async () => {
    await expect(
      new DeleteUserUseCase(build()).execute('00000000-0000-4000-8000-000000000000'),
    ).rejects.toBeInstanceOf(NotFoundError);
  });
});
