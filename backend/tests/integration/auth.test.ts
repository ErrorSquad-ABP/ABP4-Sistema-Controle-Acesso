import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { FakeTokenService, InMemoryUserRepository } from '../support/in-memory-repositories.js';

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

const users = new InMemoryUserRepository([admin]);
const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
});
const app = createApp(
  buildContainer(env, { userRepository: users, tokenService: new FakeTokenService(users) }),
);

describe('auth', () => {
  it('login -> me', async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abp4.local', password: 'DemoAdmin123!' });

    expect(login.status).toBe(200);
    expect(login.body).toMatchObject({ tokenType: 'Bearer', user: { email: 'admin@abp4.local', role: 'ADMIN' } });

    const me = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${login.body.accessToken}`);

    expect(me.status).toBe(200);
    expect(me.body).toMatchObject({ id: admin.id, email: 'admin@abp4.local', role: 'ADMIN' });
    expect(JSON.stringify(me.body)).not.toContain('scrypt$');
  });

  it('sem token, esquema errado e token invalido -> 401', async () => {
    expect((await request(app).get('/api/v1/auth/me')).status).toBe(401);
    expect((await request(app).get('/api/v1/auth/me').set('Authorization', 'Basic abc')).status).toBe(401);
    expect((await request(app).get('/api/v1/auth/me').set('Authorization', 'Bearer x')).status).toBe(401);
  });

  it('header com segmento extra -> 401', async () => {
    const login = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abp4.local', password: 'DemoAdmin123!' });

    const res = await request(app)
      .get('/api/v1/auth/me')
      .set('Authorization', `Bearer ${login.body.accessToken} extra`);

    expect(res.status).toBe(401);
  });

  it('credencial errada e e-mail inexistente -> 401 com a mesma mensagem', async () => {
    const errada = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abp4.local', password: 'errada' });
    const inexistente = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'ninguem@abp4.local', password: 'errada' });

    expect(errada.status).toBe(401);
    expect(inexistente.status).toBe(401);
    expect(errada.body.error.message).toBe('Credenciais invalidas');
    expect(inexistente.body.error.message).toBe(errada.body.error.message);
  });

  it('body invalido -> 400 com o campo', async () => {
    const res = await request(app).post('/api/v1/auth/login').send({ email: 'nao-e-email', password: 'x' });

    expect(res.status).toBe(400);
    expect(res.body.error.details).toHaveProperty('email');
  });
});
