import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { AuthorizationRecord } from '../../src/domain/authorizations/authorization.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { InMemoryAuthorizationRepository } from '../support/in-memory-authorizations.js';
import { FakeTokenService } from '../support/in-memory-repositories.js';
import { InMemoryUserAdminRepository } from '../support/in-memory-user-admin.js';

const now = Date.now();
const minute = 60_000;

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
};

const location = { id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427', name: 'Recepcao' };
const residentUser = { id: resident.id, name: resident.name, role: 'RESIDENT' as const };

function authorization(
  id: string,
  overrides: Partial<AuthorizationRecord> = {},
): AuthorizationRecord {
  return {
    id,
    user: residentUser,
    location,
    startsAt: new Date(now - 30 * minute),
    endsAt: new Date(now + 30 * minute),
    maxUses: 3,
    usedCount: 1,
    canceledAt: null,
    cancelReason: null,
    createdAt: new Date(now - 24 * 60 * minute),
    ...overrides,
  };
}

const records: AuthorizationRecord[] = [
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae01'),
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae02', {
    startsAt: new Date(now + 60 * minute),
    endsAt: new Date(now + 120 * minute),
  }),
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae03', {
    startsAt: new Date(now - 120 * minute),
    endsAt: new Date(now - 60 * minute),
  }),
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae04', {
    startsAt: new Date(now - 45 * minute),
    maxUses: 2,
    usedCount: 2,
  }),
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae05', {
    startsAt: new Date(now - 90 * minute),
    canceledAt: new Date(now - 10 * minute),
    cancelReason: 'Visita remarcada',
  }),
  authorization('6ec0bd7f-11c0-43da-975e-2a8ad9ebae06', {
    user: { id: visitor.id, name: visitor.name, role: 'VISITOR' },
  }),
];

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
      authorizationRepository: new InMemoryAuthorizationRepository(records),
      tokenService: new FakeTokenService(users),
    }),
  );

  async function token(email: string) {
    const res = await request(app).post('/api/v1/auth/login').send({ email, password: 'DemoAdmin123!' });
    return res.body.accessToken as string;
  }

  return { app, token };
}

describe('minhas autorizacoes', () => {
  it('exige token', async () => {
    const { app } = buildApp();
    expect((await request(app).get('/api/v1/me/authorizations')).status).toBe(401);
  });

  it('devolve so as autorizacoes do usuario logado', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/me/authorizations')
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);

    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ page: 1, pageSize: 20, total: 5 });
    expect(res.body.items).toHaveLength(5);
    expect(res.body.items.every((item: { user: { id: string } }) => item.user.id === resident.id)).toBe(true);

    const visitorRes = await request(app)
      .get('/api/v1/me/authorizations')
      .set('Authorization', `Bearer ${await token('vis@abp4.local')}`);
    expect(visitorRes.body.total).toBe(1);
    expect(visitorRes.body.items[0].user.id).toBe(visitor.id);

    const adminRes = await request(app)
      .get('/api/v1/me/authorizations')
      .set('Authorization', `Bearer ${await token('admin@abp4.local')}`);
    expect(adminRes.body).toMatchObject({ total: 0, items: [] });
  });

  it('ordena por startsAt desc e id desc', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/me/authorizations')
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);

    expect(res.body.items.map((item: { id: string }) => item.id)).toEqual([
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae02',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae01',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae04',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae05',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae03',
    ]);
  });

  it('calcula status e remainingUses no contrato', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/me/authorizations')
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);
    const byId = Object.fromEntries(
      res.body.items.map((item: { id: string }) => [item.id, item]),
    ) as Record<string, { status: string; remainingUses: number; canceledAt: string | null }>;

    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae01']).toMatchObject({ status: 'ACTIVE', remainingUses: 2 });
    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae02']).toMatchObject({ status: 'SCHEDULED' });
    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae03']).toMatchObject({ status: 'EXPIRED' });
    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae04']).toMatchObject({ status: 'EXPIRED', remainingUses: 0 });
    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae05']).toMatchObject({
      status: 'CANCELED',
      cancelReason: 'Visita remarcada',
    });
    expect(byId['6ec0bd7f-11c0-43da-975e-2a8ad9ebae05']?.canceledAt).toMatch(/Z$/);
  });

  it('filtra pelo status calculado', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('res@abp4.local')}`;

    const active = await request(app).get('/api/v1/me/authorizations').query({ status: 'ACTIVE' }).set('Authorization', auth);
    expect(active.status, JSON.stringify(active.body)).toBe(200);
    expect(active.body.total).toBe(1);
    expect(active.body.items.map((item: { id: string }) => item.id)).toEqual(['6ec0bd7f-11c0-43da-975e-2a8ad9ebae01']);

    const expired = await request(app).get('/api/v1/me/authorizations').query({ status: 'EXPIRED' }).set('Authorization', auth);
    expect(expired.body.total).toBe(2);
    expect(expired.body.items.every((item: { status: string }) => item.status === 'EXPIRED')).toBe(true);

    const canceled = await request(app).get('/api/v1/me/authorizations').query({ status: 'CANCELED' }).set('Authorization', auth);
    expect(canceled.body.total).toBe(1);

    const scheduled = await request(app).get('/api/v1/me/authorizations').query({ status: 'SCHEDULED' }).set('Authorization', auth);
    expect(scheduled.body.total).toBe(1);
  });

  it('pagina mantendo o total', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/me/authorizations')
      .query({ page: 2, pageSize: 2 })
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);

    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ page: 2, pageSize: 2, total: 5 });
    expect(res.body.items.map((item: { id: string }) => item.id)).toEqual([
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae04',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae05',
    ]);
  });

  it('status desconhecido -> 400', async () => {
    const { app, token } = buildApp();

    const res = await request(app)
      .get('/api/v1/me/authorizations')
      .query({ status: 'TALVEZ' })
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);

    expect(res.status).toBe(400);
    expect(res.body.error.details).toHaveProperty('status');
  });
});
