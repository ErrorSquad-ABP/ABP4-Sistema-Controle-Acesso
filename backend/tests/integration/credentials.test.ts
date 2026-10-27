import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { IssueQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import type { UserRecord } from '../../src/domain/ports/user-repository.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';
import { hashPassword } from '../../src/shared/password-hasher.js';
import {
  FakeTokenService,
  InMemoryUserRepository,
} from '../support/in-memory-repositories.js';
import { FixedClock, SequentialIds } from '../support/terminal-fakes.js';

const QR_SECRET = 'a'.repeat(64);
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

const users = new InMemoryUserRepository([admin]);
const env = loadEnv({
  NODE_ENV: 'test',
  LOG_LEVEL: 'silent',
  JWT_SECRET: 'segredo-de-teste-com-32-caracteres',
  QR_TOKEN_SECRET: QR_SECRET,
});
const app = createApp(
  buildContainer(env, { userRepository: users, tokenService: new FakeTokenService(users) }),
);
const signer = new HmacQrTokenSigner(QR_SECRET);
const now = new Date();
const issue = () =>
  new IssueQrCredentialUseCase(new FixedClock(now), new SequentialIds(), signer).execute('terminal-01');

async function token(): Promise<string> {
  const res = await request(app).post('/api/v1/auth/login').send({ email: 'admin@abp4.local', password: 'x' });
  return res.body.accessToken as string;
}

describe('POST /credentials/qr/validate', () => {
  it('exige sessao autenticada', async () => {
    const res = await request(app).post('/api/v1/credentials/qr/validate').send({
      qrToken: issue().token,
      terminalId: 'terminal-01',
    });

    expect(res.status).toBe(401);
  });

  it('valida credencial emitida para o terminal', async () => {
    const credential = issue();
    const res = await request(app)
      .post('/api/v1/credentials/qr/validate')
      .set('Authorization', `Bearer ${await token()}`)
      .send({ qrToken: credential.token, terminalId: 'terminal-01' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({
      valid: true,
      terminalId: 'terminal-01',
      expiresAt: new Date(credential.expiresAt).toISOString(),
    });
  });

  it('rejeita assinatura adulterada e terminal divergente', async () => {
    const credential = issue();
    const tampered = `${credential.token.slice(0, -1)}${credential.token.endsWith('A') ? 'B' : 'A'}`;
    const auth = `Bearer ${await token()}`;

    for (const body of [
      { qrToken: tampered, terminalId: 'terminal-01' },
      { qrToken: credential.token, terminalId: 'terminal-02' },
    ]) {
      const res = await request(app)
        .post('/api/v1/credentials/qr/validate')
        .set('Authorization', auth)
        .send(body);
      expect(res.status).toBe(200);
      expect(res.body).toEqual({ valid: false });
    }
  });

  it('rejeita credencial expirada', async () => {
    const old = new IssueQrCredentialUseCase(
      new FixedClock(new Date(Date.now() - 20_000)),
      new SequentialIds(),
      signer,
    ).execute('terminal-01');

    const res = await request(app)
      .post('/api/v1/credentials/qr/validate')
      .set('Authorization', `Bearer ${await token()}`)
      .send({ qrToken: old.token, terminalId: 'terminal-01' });

    expect(res.status).toBe(200);
    expect(res.body).toEqual({ valid: false });
  });

  it('body invalido -> 400', async () => {
    const res = await request(app)
      .post('/api/v1/credentials/qr/validate')
      .set('Authorization', `Bearer ${await token()}`)
      .send({ qrToken: '', terminalId: 'Terminal 01' });

    expect(res.status).toBe(400);
  });
});
