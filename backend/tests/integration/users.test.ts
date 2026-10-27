import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { FakeTokenService } from '../support/in-memory-repositories.js';
import { InMemoryUserAdminRepository } from '../support/in-memory-user-admin.js';

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
const resident: UserRecord = {
  ...base,
  id: '8c9e6679-7425-40de-944b-e07fc1f90ae8',
  name: 'Residente',
  email: 'res@abp4.local',
  role: 'RESIDENT',
};
const visitor: UserRecord = {
  ...base,
  id: '9c9e6679-7425-40de-944b-e07fc1f90ae9',
  name: 'Visitante',
  email: 'vis@abp4.local',
  role: 'VISITOR',
  active: false,
};

const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
});

function buildApp() {
  const users = new InMemoryUserAdminRepository([base, resident, visitor]);
  const app = createApp(
    buildContainer(env, {
      userRepository: users,
      userAdminRepository: users,
      tokenService: new FakeTokenService(users),
    }),
  );

  async function token(email = 'admin@abp4.local', password = 'DemoAdmin123!') {
    const res = await request(app).post('/api/v1/auth/login').send({ email, password });
    return res.body.accessToken as string;
  }

  return { app, users, token };
}

describe('usuarios (ADMIN)', () => {
  it('exige token e perfil ADMIN', async () => {
    const { app, token } = buildApp();

    expect((await request(app).get('/api/v1/users')).status).toBe(401);

    const residentToken = await token('res@abp4.local', 'DemoAdmin123!');
    const forbidden = [
      request(app).get(`/api/v1/users/${resident.id}`),
      request(app).post('/api/v1/users').send({ name: 'Nao Pode' }),
      request(app).patch(`/api/v1/users/${resident.id}`).send({ name: 'Nao Pode' }),
      request(app).delete(`/api/v1/users/${resident.id}`),
    ];
    for (const res of await Promise.all(forbidden.map((req) => req.set('Authorization', `Bearer ${residentToken}`)))) {
      expect(res.status).toBe(403);
    }
  });

  it('lista com filtros, paginacao e sem hash', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const all = await request(app).get('/api/v1/users').set('Authorization', auth);
    expect(all.status, JSON.stringify(all.body)).toBe(200);
    expect(all.body).toMatchObject({ page: 1, pageSize: 20, total: 3 });
    expect(JSON.stringify(all.body)).not.toContain('scrypt$');

    const visitors = await request(app).get('/api/v1/users').query({ role: 'VISITOR' }).set('Authorization', auth);
    expect(visitors.body.items.map((u: { email: string }) => u.email)).toEqual(['vis@abp4.local']);

    const active = await request(app).get('/api/v1/users').query({ active: 'true' }).set('Authorization', auth);
    expect(active.body.total).toBe(2);

    const search = await request(app).get('/api/v1/users').query({ search: 'res' }).set('Authorization', auth);
    expect(search.body.items.map((u: { email: string }) => u.email)).toEqual(['res@abp4.local']);

    const page = await request(app).get('/api/v1/users').query({ page: 2, pageSize: 2 }).set('Authorization', auth);
    expect(page.body).toMatchObject({ page: 2, pageSize: 2, total: 3 });
    expect(page.body.items).toHaveLength(1);
  });

  it('query invalida -> 400', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/users')
      .query({ role: 'TALVEZ' })
      .set('Authorization', `Bearer ${await token()}`);

    expect(res.status).toBe(400);
    expect(res.body.error.details).toHaveProperty('role');
  });

  it('cria usuario com 201, normaliza e-mail e permite login com a senha nova', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const res = await request(app).post('/api/v1/users').set('Authorization', auth).send({
      name: 'Maria Souza',
      email: 'Maria.Souza@Exemplo.com',
      password: 'senha-forte-123',
      role: 'VISITOR',
    });

    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body).toMatchObject({ name: 'Maria Souza', email: 'maria.souza@exemplo.com', role: 'VISITOR', active: true });
    expect(JSON.stringify(res.body)).not.toContain('scrypt$');
    expect(JSON.stringify(res.body)).not.toContain('senha-forte-123');

    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'maria.souza@exemplo.com', password: 'senha-forte-123' });
    expect(login.status).toBe(200);
    expect(login.body.user.email).toBe('maria.souza@exemplo.com');
  });

  it('e-mail duplicado -> 409', async () => {
    const { app, token } = buildApp();

    const res = await request(app).post('/api/v1/users').set('Authorization', `Bearer ${await token()}`).send({
      name: 'Outro',
      email: 'ADMIN@abp4.local',
      password: 'senha-forte-123',
      role: 'VISITOR',
    });

    expect(res.status).toBe(409);
    expect(res.body.error.code).toBe('CONFLICT');
  });

  it('body invalido -> 400', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const curto = await request(app)
      .post('/api/v1/users')
      .set('Authorization', auth)
      .send({ name: 'X', email: 'nao-e-email', password: '123', role: 'SINDICO' });
    expect(curto.status).toBe(400);
    expect(curto.body.error.details).toHaveProperty('password');

    const vazio = await request(app)
      .patch('/api/v1/users/8c9e6679-7425-40de-944b-e07fc1f90ae8')
      .set('Authorization', auth)
      .send({});
    expect(vazio.status).toBe(400);
  });

  it('detalha por id, 404 para id inexistente e 400 para id invalido', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const ok = await request(app).get(`/api/v1/users/${resident.id}`).set('Authorization', auth);
    expect(ok.status).toBe(200);
    expect(ok.body).toMatchObject({ id: resident.id, email: 'res@abp4.local' });

    expect(
      (await request(app).get('/api/v1/users/00000000-0000-4000-8000-000000000000').set('Authorization', auth)).status,
    ).toBe(404);
    expect((await request(app).get('/api/v1/users/123').set('Authorization', auth)).status).toBe(400);
  });

  it('atualiza parcialmente e recusa e-mail de outro usuario', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const patch = await request(app)
      .patch(`/api/v1/users/${resident.id}`)
      .set('Authorization', auth)
      .send({ role: 'VISITOR', name: 'Residente Editado' });
    expect(patch.status, JSON.stringify(patch.body)).toBe(200);
    expect(patch.body).toMatchObject({ name: 'Residente Editado', role: 'VISITOR', email: 'res@abp4.local' });

    const conflito = await request(app)
      .patch(`/api/v1/users/${resident.id}`)
      .set('Authorization', auth)
      .send({ email: 'admin@abp4.local' });
    expect(conflito.status).toBe(409);

    const desconhecido = await request(app)
      .patch('/api/v1/users/00000000-0000-4000-8000-000000000000')
      .set('Authorization', auth)
      .send({ name: 'Ninguem' });
    expect(desconhecido.status).toBe(404);
  });

  it('desativar pelo PATCH bloqueia o login na hora', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const patch = await request(app)
      .patch(`/api/v1/users/${resident.id}`)
      .set('Authorization', auth)
      .send({ active: false });
    expect(patch.status).toBe(200);
    expect(patch.body.active).toBe(false);

    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'res@abp4.local', password: 'DemoAdmin123!' });
    expect(login.status).toBe(401);
  });

  it('DELETE e exclusao logica: 204, cadastro preservado e login negado', async () => {
    const { app, token, users } = buildApp();
    const auth = `Bearer ${await token()}`;

    const res = await request(app).delete(`/api/v1/users/${resident.id}`).set('Authorization', auth);
    expect(res.status).toBe(204);
    expect(res.body).toEqual({});

    const stored = await users.findById(resident.id);
    expect(stored).toMatchObject({ id: resident.id, active: false });

    const detail = await request(app).get(`/api/v1/users/${resident.id}`).set('Authorization', auth);
    expect(detail.status).toBe(200);
    expect(detail.body.active).toBe(false);

    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'res@abp4.local', password: 'DemoAdmin123!' });
    expect(login.status).toBe(401);

    expect(
      (await request(app).delete('/api/v1/users/00000000-0000-4000-8000-000000000000').set('Authorization', auth)).status,
    ).toBe(404);
  });
});
