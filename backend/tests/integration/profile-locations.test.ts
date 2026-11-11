import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { LocationRecord } from '../../src/domain/ports/location-repository.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { InMemoryLocationRepository } from '../support/in-memory-locations.js';
import { FakeTokenService } from '../support/in-memory-repositories.js';
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

const reception: LocationRecord = {
  id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427',
  name: 'Edificio Aurora - Recepcao',
  description: 'Av. Central, 1200',
  latitude: -23.1857,
  longitude: -45.8846,
  radiusMeters: 100,
  isActive: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const garage: LocationRecord = {
  ...reception,
  id: '2b4e28ba-2fa1-41d2-883f-0016d3cca428',
  name: 'Edificio Aurora - Garagem',
  isActive: false,
};

const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
});

function buildApp() {
  const users = new InMemoryUserAdminRepository([admin, resident]);
  const locations = new InMemoryLocationRepository([reception, garage]);
  const app = createApp(
    buildContainer(env, {
      userRepository: users,
      userAdminRepository: users,
      locationRepository: locations,
      tokenService: new FakeTokenService(users),
    }),
  );

  async function token(email = 'admin@abp4.local', password = 'DemoAdmin123!') {
    const res = await request(app).post('/api/v1/auth/login').send({ email, password });
    return res.body.accessToken as string;
  }

  return { app, users, locations, token };
}

describe('PATCH /me', () => {
  it('exige sessao', async () => {
    const { app } = buildApp();
    const res = await request(app).patch('/api/v1/me').send({ name: 'Sem Sessao' });
    expect(res.status).toBe(401);
  });

  it('muda o nome e devolve o mesmo shape de GET /auth/me', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('res@abp4.local')}`;

    const res = await request(app).patch('/api/v1/me').set('Authorization', auth).send({ name: 'Residente Editado' });
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({
      id: resident.id,
      name: 'Residente Editado',
      email: 'res@abp4.local',
      role: 'RESIDENT',
      active: true,
    });
    expect(JSON.stringify(res.body)).not.toContain('scrypt$');

    const me = await request(app).get('/api/v1/auth/me').set('Authorization', auth);
    expect(me.body.name).toBe('Residente Editado');
  });

  it('ignora papel no corpo e nunca troca o proprio perfil', async () => {
    const { app, token, users } = buildApp();
    const auth = `Bearer ${await token('res@abp4.local')}`;

    const res = await request(app)
      .patch('/api/v1/me')
      .set('Authorization', auth)
      .send({ name: 'Residente Editado', role: 'ADMIN', email: 'outro@abp4.local', active: false });

    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ name: 'Residente Editado', role: 'RESIDENT', email: 'res@abp4.local', active: true });
    expect(await users.findById(resident.id)).toMatchObject({ role: 'RESIDENT', active: true });
  });

  it('corpo sem campo editavel ou invalido -> 400', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token('res@abp4.local')}`;

    const vazio = await request(app).patch('/api/v1/me').set('Authorization', auth).send({});
    expect(vazio.status).toBe(400);

    const soPapel = await request(app).patch('/api/v1/me').set('Authorization', auth).send({ role: 'ADMIN' });
    expect(soPapel.status).toBe(400);

    const curto = await request(app).patch('/api/v1/me').set('Authorization', auth).send({ name: 'X' });
    expect(curto.status).toBe(400);
    expect(curto.body.error.details).toHaveProperty('name');
  });
});

describe('locais de acesso', () => {
  it('GET exige sessao e lista so os ativos, paginado', async () => {
    const { app, token } = buildApp();

    expect((await request(app).get('/api/v1/locations')).status).toBe(401);

    const res = await request(app).get('/api/v1/locations').set('Authorization', `Bearer ${await token('res@abp4.local')}`);
    expect(res.status, JSON.stringify(res.body)).toBe(200);
    expect(res.body).toMatchObject({ page: 1, pageSize: 20, total: 1 });
    expect(res.body.items).toHaveLength(1);
    expect(res.body.items[0]).toMatchObject({
      id: reception.id,
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 100,
      isActive: true,
    });
    expect(JSON.stringify(res.body)).not.toContain(garage.id);

    const page2 = await request(app)
      .get('/api/v1/locations')
      .query({ page: 2, pageSize: 1 })
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`);
    expect(page2.body).toMatchObject({ page: 2, pageSize: 1, total: 1 });
    expect(page2.body.items).toHaveLength(0);
  });

  it('POST e restrito a ADMIN', async () => {
    const { app, token, locations } = buildApp();
    const body = { name: 'Edificio Aurora - Sala 2', latitude: -23.1857, longitude: -45.8846, radiusMeters: 40 };

    const negado = await request(app)
      .post('/api/v1/locations')
      .set('Authorization', `Bearer ${await token('res@abp4.local')}`)
      .send(body);
    expect(negado.status).toBe(403);
    expect((await locations.listActive({ page: 1, pageSize: 20 })).total).toBe(1);
  });

  it('ADMIN cria local com raio padrao 100 e descricao opcional', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;

    const res = await request(app)
      .post('/api/v1/locations')
      .set('Authorization', auth)
      .send({ name: 'Edificio Aurora - Sala 2', latitude: -23.1857, longitude: -45.8846 });

    expect(res.status, JSON.stringify(res.body)).toBe(201);
    expect(res.body).toMatchObject({
      name: 'Edificio Aurora - Sala 2',
      description: null,
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 100,
      isActive: true,
    });

    const list = await request(app).get('/api/v1/locations').set('Authorization', auth);
    expect(list.body.total).toBe(2);
    expect(list.body.items.map((location: { name: string }) => location.name)).toEqual([
      'Edificio Aurora - Recepcao',
      'Edificio Aurora - Sala 2',
    ]);
  });

  it('POST recusa raio fora de 1..100 e coordenadas invalidas', async () => {
    const { app, token } = buildApp();
    const auth = `Bearer ${await token()}`;
    const base = { name: 'Edificio Aurora', latitude: -23.1857, longitude: -45.8846, radiusMeters: 100 };

    for (const radiusMeters of [0, 101, 50.5]) {
      const res = await request(app).post('/api/v1/locations').set('Authorization', auth).send({ ...base, radiusMeters });
      expect(res.status, `raio ${radiusMeters}`).toBe(400);
      expect(res.body.error.details).toHaveProperty('radiusMeters');
    }

    const latitude = await request(app).post('/api/v1/locations').set('Authorization', auth).send({ ...base, latitude: 91 });
    expect(latitude.status).toBe(400);
    expect(latitude.body.error.details).toHaveProperty('latitude');

    const longitude = await request(app).post('/api/v1/locations').set('Authorization', auth).send({ ...base, longitude: -181 });
    expect(longitude.status).toBe(400);
    expect(longitude.body.error.details).toHaveProperty('longitude');

    const nome = await request(app).post('/api/v1/locations').set('Authorization', auth).send({ ...base, name: 'X' });
    expect(nome.status).toBe(400);
    expect(nome.body.error.details).toHaveProperty('name');

    const vazio = await request(app).post('/api/v1/locations').set('Authorization', auth).send({});
    expect(vazio.status).toBe(400);
  });
});
