import { Router } from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { NotFoundError, ValidationError } from '../../src/domain/errors/domain-error.js';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';

// Rotas que so existem no teste, para exercitar o error handler.
const probe = Router();
probe.get('/__probe/not-found', () => {
  throw new NotFoundError('Autorizacao nao encontrada');
});
probe.get('/__probe/domain-validation', () => {
  throw new ValidationError('Janela de horario invalida', { field: 'horaFim' });
});
probe.get('/__probe/async-boom', async () => {
  throw new Error('segredo do banco');
});
probe.post('/__probe/zod', (req, res) => {
  const body = z.object({ nome: z.string().min(1) }).parse(req.body);
  res.status(201).json(body);
});

const env = loadEnv({ NODE_ENV: 'test', LOG_LEVEL: 'silent', APP_VERSION: 'test-sha', QR_TOKEN_SECRET: 'a'.repeat(64) });
const app = createApp(buildContainer(env), { extraRoutes: [probe] });

describe('GET /health', () => {
  it('responde 200 com database ok quando o banco responde', async () => {
    const comBanco = createApp(buildContainer(env, { databaseProbe: { ping: () => Promise.resolve() } }));

    const res = await request(comBanco).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', database: 'ok' });
  });

  it('responde 503 sem vazar detalhes quando o banco esta indisponivel', async () => {
    const semBanco = createApp(
      buildContainer(env, { databaseProbe: { ping: () => Promise.reject(new Error('senha do banco')) } }),
    );

    const res = await request(semBanco).get('/health');

    expect(res.status).toBe(503);
    expect(res.body).toMatchObject({ status: 'error', database: 'unavailable' });
    expect(JSON.stringify(res.body)).not.toContain('senha do banco');
  });

  it('responde 200 com o status do servico', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({
      status: 'ok',
      version: 'test-sha',
      database: 'not_configured',
    });
    expect(res.body.uptimeSeconds).toBeTypeOf('number');
    expect(new Date(res.body.timestamp).toISOString()).toBe(res.body.timestamp);
    expect(res.headers['x-powered-by']).toBeUndefined();
  });
});

describe('POST /qr-credentials/validate', () => {
  it('valida token emitido e retorna somente o resultado', async () => {
    const { IssueQrCredentialUseCase } = await import('../../src/application/terminal/qr-credential.use-cases.js');
    const { HmacQrTokenSigner } = await import('../../src/infrastructure/ids/hmac-qr-token-signer.js');
    const { SystemClock } = await import('../../src/infrastructure/clock/system-clock.js');
    const issuer = new IssueQrCredentialUseCase(new SystemClock(), { uuid: () => 'random-id', token: () => '' }, new HmacQrTokenSigner(env.QR_TOKEN_SECRET));
    const credential = issuer.execute('terminal-01');
    const res = await request(app).post('/qr-credentials/validate').send({ token: credential.token, terminalId: 'terminal-01' });
    expect(res.status).toBe(200);
    expect(res.body).toEqual({ valid: true });
    expect(JSON.stringify(res.body)).not.toContain(credential.token);
  });
});

describe('error handler padrao', () => {
  it('rota inexistente -> 404 ROUTE_NOT_FOUND', async () => {
    const res = await request(app).get('/nao-existe');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({
      error: { code: 'ROUTE_NOT_FOUND', message: 'Rota GET /nao-existe nao encontrada' },
    });
  });

  it('NotFoundError do dominio -> 404', async () => {
    const res = await request(app).get('/__probe/not-found');

    expect(res.status).toBe(404);
    expect(res.body).toEqual({ error: { code: 'NOT_FOUND', message: 'Autorizacao nao encontrada' } });
  });

  it('ValidationError do dominio -> 422 com details', async () => {
    const res = await request(app).get('/__probe/domain-validation');

    expect(res.status).toBe(422);
    expect(res.body.error).toEqual({
      code: 'VALIDATION_ERROR',
      message: 'Janela de horario invalida',
      details: { field: 'horaFim' },
    });
  });

  it('ZodError -> 400 INVALID_REQUEST com erros por campo', async () => {
    const res = await request(app).post('/__probe/zod').send({ nome: '' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
    expect(res.body.error.details).toHaveProperty('nome');
  });

  it('JSON malformado -> 400 INVALID_JSON', async () => {
    const res = await request(app)
      .post('/__probe/zod')
      .set('Content-Type', 'application/json')
      .send('{"nome":');

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_JSON');
  });

  it('erro inesperado (async) -> 500 generico, sem vazar detalhes', async () => {
    const res = await request(app).get('/__probe/async-boom');

    expect(res.status).toBe(500);
    expect(res.body).toEqual({ error: { code: 'INTERNAL_ERROR', message: 'Erro interno do servidor' } });
    expect(JSON.stringify(res.body)).not.toContain('segredo');
  });
});
