import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { AuthorizationRecord } from '../../src/domain/authorizations/authorization.js';
import type { AuthorizationRepository } from '../../src/domain/ports/authorization-repository.js';
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

const ids = {
  active: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae01',
  scheduled: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae02',
  expired: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae03',
  exhausted: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae04',
  canceled: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae05',
  visitor: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae06',
} as const;

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

/** Cada teste recebe o proprio conjunto: cancelar muta o registro. */
function fixtureRecords(): AuthorizationRecord[] {
  return [
    authorization(ids.active),
    authorization(ids.scheduled, {
      startsAt: new Date(now + 60 * minute),
      endsAt: new Date(now + 120 * minute),
    }),
    authorization(ids.expired, {
      startsAt: new Date(now - 120 * minute),
      endsAt: new Date(now - 60 * minute),
    }),
    authorization(ids.exhausted, {
      startsAt: new Date(now - 45 * minute),
      maxUses: 2,
      usedCount: 2,
    }),
    authorization(ids.canceled, {
      startsAt: new Date(now - 90 * minute),
      canceledAt: new Date(now - 10 * minute),
      cancelReason: 'Visita remarcada',
    }),
    authorization(ids.visitor, {
      user: { id: visitor.id, name: visitor.name, role: 'VISITOR' },
    }),
  ];
}

/** Segura as duas leituras do cancelamento para as duas requisicoes verem o estado ACTIVE. */
class RacingCancelRepository extends InMemoryAuthorizationRepository {
  private waiting: Array<() => void> = [];
  private gates = 2;

  override async findById(id: string): Promise<AuthorizationRecord | null> {
    const record = await super.findById(id);
    const snapshot = record ? structuredClone(record) : null;
    if (this.gates === 0) return snapshot;

    this.gates -= 1;
    if (this.gates === 1) {
      await new Promise<void>((resolve) => this.waiting.push(resolve));
    } else {
      this.waiting.shift()?.();
    }
    return snapshot;
  }
}

const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
});

function buildApp(authorizationRepository?: AuthorizationRepository) {
  const users = new InMemoryUserAdminRepository([base, resident, visitor]);
  const app = createApp(
    buildContainer(env, {
      userRepository: users,
      userAdminRepository: users,
      authorizationRepository: authorizationRepository ?? new InMemoryAuthorizationRepository(fixtureRecords()),
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
      ids.scheduled,
      ids.active,
      ids.exhausted,
      ids.canceled,
      ids.expired,
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

    expect(byId[ids.active]).toMatchObject({ status: 'ACTIVE', remainingUses: 2 });
    expect(byId[ids.scheduled]).toMatchObject({ status: 'SCHEDULED' });
    expect(byId[ids.expired]).toMatchObject({ status: 'EXPIRED' });
    expect(byId[ids.exhausted]).toMatchObject({ status: 'EXPIRED', remainingUses: 0 });
    expect(byId[ids.canceled]).toMatchObject({
      status: 'CANCELED',
      cancelReason: 'Visita remarcada',
    });
    expect(byId[ids.canceled]?.canceledAt).toMatch(/Z$/);
  });

  it('filtra pelo status calculado', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('res@abp4.local')}`;

    const active = await request(app).get('/api/v1/me/authorizations').query({ status: 'ACTIVE' }).set('Authorization', auth);
    expect(active.status, JSON.stringify(active.body)).toBe(200);
    expect(active.body.total).toBe(1);
    expect(active.body.items.map((item: { id: string }) => item.id)).toEqual([ids.active]);

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
      ids.exhausted,
      ids.canceled,
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

describe('autorizacoes administrativas (US-16/17)', () => {
  it('cria com ADMIN e recusa perfil comum', async () => {
    const { app, token } = buildApp();
    const body = { userId: resident.id, locationId: location.id, startsAt: new Date(now + minute).toISOString(), endsAt: new Date(now + 60 * minute).toISOString(), maxUses: 2 };
    const admin = await request(app).post('/api/v1/authorizations').set('Authorization', `Bearer ${await token('admin@abp4.local')}`).send(body);
    expect(admin.status, JSON.stringify(admin.body)).toBe(201);
    expect(admin.body).toMatchObject({ user: { id: resident.id }, location: { id: location.id }, maxUses: 2, usedCount: 0, status: 'SCHEDULED' });
    const user = await request(app).post('/api/v1/authorizations').set('Authorization', `Bearer ${await token('res@abp4.local')}`).send(body);
    expect(user.status).toBe(403);
  });

  it('recusa janela invalida e limite de usos invalido', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('admin@abp4.local')}`;
    const body = {
      userId: resident.id,
      locationId: location.id,
      startsAt: new Date(now + 60 * minute).toISOString(),
      endsAt: new Date(now + minute).toISOString(),
      maxUses: 2,
    };

    const window = await request(app).post('/api/v1/authorizations').set('Authorization', auth).send(body);
    expect(window.status, JSON.stringify(window.body)).toBe(400);
    expect(window.body.error.details).toHaveProperty('endsAt');

    const uses = await request(app)
      .post('/api/v1/authorizations')
      .set('Authorization', auth)
      .send({ ...body, startsAt: new Date(now + minute).toISOString(), endsAt: new Date(now + 60 * minute).toISOString(), maxUses: 0 });
    expect(uses.status, JSON.stringify(uses.body)).toBe(400);
    expect(uses.body.error.details).toHaveProperty('maxUses');
  });

  it('lista com filtros e paginação, e só ADMIN consulta a lista', async () => {
    const { app, token } = buildApp();
    const adminToken = await token('admin@abp4.local');
    const res = await request(app).get('/api/v1/authorizations').query({ userId: resident.id, status: 'ACTIVE', pageSize: 1 }).set('Authorization', `Bearer ${adminToken}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ total: 1, page: 1, pageSize: 1, items: [{ status: 'ACTIVE' }] });
    const denied = await request(app).get('/api/v1/authorizations').set('Authorization', `Bearer ${await token('res@abp4.local')}`);
    expect(denied.status).toBe(403);
  });

  it('combina o filtro de periodo com o status', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('admin@abp4.local')}`;
    const period = {
      userId: resident.id,
      from: new Date(now - 40 * minute).toISOString(),
      to: new Date(now + 90 * minute).toISOString(),
    };

    const active = await request(app).get('/api/v1/authorizations').query({ ...period, status: 'ACTIVE' }).set('Authorization', auth);
    expect(active.status, JSON.stringify(active.body)).toBe(200);
    expect(active.body.total).toBe(1);
    expect(active.body.items.map((item: { id: string }) => item.id)).toEqual([ids.active]);

    const scheduled = await request(app).get('/api/v1/authorizations').query({ ...period, status: 'SCHEDULED' }).set('Authorization', auth);
    expect(scheduled.status, JSON.stringify(scheduled.body)).toBe(200);
    expect(scheduled.body.total).toBe(1);
    expect(scheduled.body.items.map((item: { id: string }) => item.id)).toEqual([ids.scheduled]);
  });

  it('pagina a lista administrativa na segunda pagina', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('admin@abp4.local')}`;

    const first = await request(app).get('/api/v1/authorizations').query({ page: 1, pageSize: 2 }).set('Authorization', auth);
    const second = await request(app).get('/api/v1/authorizations').query({ page: 2, pageSize: 2 }).set('Authorization', auth);

    expect(first.status, JSON.stringify(first.body)).toBe(200);
    expect(first.body).toMatchObject({ page: 1, pageSize: 2, total: 6 });
    expect(first.body.items.map((item: { id: string }) => item.id)).toEqual([ids.scheduled, ids.visitor]);
    expect(second.body).toMatchObject({ page: 2, pageSize: 2, total: 6 });
    expect(second.body.items.map((item: { id: string }) => item.id)).toEqual([ids.active, ids.exhausted]);
  });

  it('detalha a propria autorizacao e esconde a de outro usuario', async () => {
    const { app, token } = buildApp();
    const residentToken = await token('res@abp4.local');

    const own = await request(app).get(`/api/v1/authorizations/${ids.active}`).set('Authorization', `Bearer ${residentToken}`);
    expect(own.status, JSON.stringify(own.body)).toBe(200);
    expect(own.body).toMatchObject({ id: ids.active, user: { id: resident.id } });

    const another = await request(app).get(`/api/v1/authorizations/${ids.visitor}`).set('Authorization', `Bearer ${residentToken}`);
    expect(another.status).toBe(404);

    const asAdmin = await request(app).get(`/api/v1/authorizations/${ids.visitor}`).set('Authorization', `Bearer ${await token('admin@abp4.local')}`);
    expect(asAdmin.status, JSON.stringify(asAdmin.body)).toBe(200);
  });

  it('cancela autorização ativa com motivo e rejeita expirada', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('admin@abp4.local')}`;
    const canceled = await request(app).post(`/api/v1/authorizations/${ids.active}/cancel`).set('Authorization', auth).send({ reason: 'Remarcada' });
    expect(canceled.status, JSON.stringify(canceled.body)).toBe(200);
    expect(canceled.body).toMatchObject({ status: 'CANCELED', cancelReason: 'Remarcada' });
    const expired = await request(app).post(`/api/v1/authorizations/${ids.expired}/cancel`).set('Authorization', auth);
    expect(expired.status).toBe(409);
  });

  it('nao cancela duas vezes a mesma autorizacao', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('admin@abp4.local')}`;

    const already = await request(app).post(`/api/v1/authorizations/${ids.canceled}/cancel`).set('Authorization', auth).send({ reason: 'Outro motivo' });
    expect(already.status, JSON.stringify(already.body)).toBe(409);

    const detail = await request(app).get(`/api/v1/authorizations/${ids.canceled}`).set('Authorization', auth);
    expect(detail.body).toMatchObject({ status: 'CANCELED', cancelReason: 'Visita remarcada' });
  });

  it('cancelamento concorrente: uma escrita vence e a outra recebe 409', async () => {
    const repository = new RacingCancelRepository(fixtureRecords());
    const { app, token } = buildApp(repository);
    const auth = `Bearer ${await token('admin@abp4.local')}`;

    const responses = await Promise.all([
      request(app).post(`/api/v1/authorizations/${ids.active}/cancel`).set('Authorization', auth).send({ reason: 'Primeiro motivo' }),
      request(app).post(`/api/v1/authorizations/${ids.active}/cancel`).set('Authorization', auth).send({ reason: 'Segundo motivo' }),
    ]);

    expect(responses.map((response) => response.status).sort()).toEqual([200, 409]);
    const winner = responses.find((response) => response.status === 200);

    const detail = await request(app).get(`/api/v1/authorizations/${ids.active}`).set('Authorization', auth);
    expect(detail.body).toMatchObject({ status: 'CANCELED' });
    expect(detail.body.cancelReason).toBe(winner?.body.cancelReason);
  });

  it('cancelar id inexistente -> 404', async () => {
    const { app, token } = buildApp();
    const res = await request(app)
      .post('/api/v1/authorizations/6ec0bd7f-11c0-43da-975e-2a8ad9ebaeff/cancel')
      .set('Authorization', `Bearer ${await token('admin@abp4.local')}`);
    expect(res.status).toBe(404);
  });
});
