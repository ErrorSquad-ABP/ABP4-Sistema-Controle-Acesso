import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { createRateLimit } from '../../src/main/http/middlewares/rate-limit.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import { FakeTokenService, InMemoryUserRepository } from '../support/in-memory-repositories.js';

const user: UserRecord = {
  id: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  name: 'Admin',
  email: 'admin@abp4.local',
  passwordHash: hashPassword('x', 'salt'),
  role: 'ADMIN',
  active: true,
  createdAt: new Date(),
  updatedAt: new Date(),
};

describe('rate limit', () => {
  it('bloqueia com 429 no formato de erro da API', async () => {
    const app = express();
    app.post(
      '/probe',
      createRateLimit({ windowMs: 60_000, limit: 3, message: 'Muitas tentativas' }),
      (_req, res) => {
        res.status(401).json({ ok: false });
      },
    );

    const statuses: number[] = [];
    for (let attempt = 0; attempt < 4; attempt += 1) {
      statuses.push((await request(app).post('/probe')).status);
    }

    expect(statuses).toEqual([401, 401, 401, 429]);

    const blocked = await request(app).post('/probe');
    expect(blocked.body.error).toMatchObject({ code: 'TOO_MANY_REQUESTS', message: 'Muitas tentativas' });
  });

  it('o login real responde com o header RateLimit', async () => {
    const env = loadEnv({ NODE_ENV: 'test', LOG_LEVEL: 'silent' });
    const users = new InMemoryUserRepository([user]);
    const app = createApp(
      buildContainer(env, { userRepository: users, tokenService: new FakeTokenService(users) }),
    );

    const res = await request(app)
      .post('/api/v1/auth/login')
      .send({ email: 'admin@abp4.local', password: 'errada' });

    expect(res.status).toBe(401);
    expect(res.headers.ratelimit ?? res.headers['ratelimit-policy']).toBeDefined();
  });
});
