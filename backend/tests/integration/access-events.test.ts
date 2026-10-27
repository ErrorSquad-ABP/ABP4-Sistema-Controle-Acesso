import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { AccessEventView } from '../../src/domain/ports/access-event-repository.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { InMemoryAccessEventRepository } from '../support/in-memory-access-events.js';
import { FakeTokenService, InMemoryUserRepository } from '../support/in-memory-repositories.js';

const admin: UserRecord = {
  id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  name: 'Admin',
  email: 'admin@abp4.local',
  passwordHash: hashPassword('x', 'salt'),
  role: 'ADMIN',
  active: true,
  createdAt: new Date(),
  updatedAt: new Date(),
};
const resident: UserRecord = {
  ...admin,
  id: '8c9e6679-7425-40de-944b-e07fc1f90ae8',
  name: 'Residente',
  email: 'res@abp4.local',
  role: 'RESIDENT',
};

const events: AccessEventView[] = [
  {
    id: 'b0000000-0000-4000-8000-000000000001',
    occurredAt: '2026-10-20T12:00:00.000Z',
    terminalId: 'terminal-01',
    method: 'QR',
    decision: 'GRANTED',
    reason: null,
    user: { id: resident.id, name: resident.name, role: 'RESIDENT' },
    location: { id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427', name: 'Recepcao' },
    authorizationId: null,
    distanceMeters: 3,
  },
  {
    id: 'b0000000-0000-4000-8000-000000000002',
    occurredAt: '2026-10-19T12:00:00.000Z',
    terminalId: 'terminal-01',
    method: 'NFC',
    decision: 'DENIED',
    reason: 'NO_AUTHORIZATION',
    user: { id: admin.id, name: admin.name, role: 'ADMIN' },
    location: { id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427', name: 'Recepcao' },
    authorizationId: null,
    distanceMeters: null,
  },
];

const users = new InMemoryUserRepository([admin, resident]);
const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
});
const app = createApp(
  buildContainer(env, {
    userRepository: users,
    accessEventRepository: new InMemoryAccessEventRepository(events),
    tokenService: new FakeTokenService(users),
  }),
);

async function tokenFor(email: string): Promise<string> {
  const res = await request(app).post('/api/v1/auth/login').send({ email, password: 'x' });
  return res.body.accessToken as string;
}

describe('historico de acessos', () => {
  it('exige token', async () => {
    expect((await request(app).get('/api/v1/me/access-events')).status).toBe(401);
  });

  it('usuario comum recebe so os proprios eventos', async () => {
    const res = await request(app)
      .get('/api/v1/me/access-events')
      .set('Authorization', `Bearer ${await tokenFor('res@abp4.local')}`);

    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0].user.id).toBe(resident.id);
  });

  it('rota admin nega perfil comum e aceita admin', async () => {
    const negado = await request(app)
      .get('/api/v1/access-events')
      .set('Authorization', `Bearer ${await tokenFor('res@abp4.local')}`);
    expect(negado.status).toBe(403);

    const ok = await request(app)
      .get('/api/v1/access-events')
      .set('Authorization', `Bearer ${await tokenFor('admin@abp4.local')}`);
    expect(ok.status, JSON.stringify(ok.body)).toBe(200);
    expect(ok.body.total).toBe(2);
  });

  it('filtra por decisao e periodo', async () => {
    const res = await request(app)
      .get('/api/v1/access-events')
      .query({ decision: 'DENIED', from: '2026-10-19T00:00:00Z', to: '2026-10-19T23:59:59Z' })
      .set('Authorization', `Bearer ${await tokenFor('admin@abp4.local')}`);

    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body.items.map((event: { id: string }) => event.id)).toEqual([events[1]?.id]);
  });

  it('query invalida -> 400', async () => {
    const res = await request(app)
      .get('/api/v1/access-events')
      .query({ decision: 'TALVEZ' })
      .set('Authorization', `Bearer ${await tokenFor('admin@abp4.local')}`);

    expect(res.status).toBe(400);
  });
});
