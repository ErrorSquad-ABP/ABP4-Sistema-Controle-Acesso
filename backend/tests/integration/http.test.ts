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

const env = loadEnv({ NODE_ENV: 'test', LOG_LEVEL: 'silent', APP_VERSION: 'test-sha' });
const app = createApp(buildContainer(env), { extraRoutes: [probe] });

describe('GET /health', () => {
  it('responde 200 com o status do servico', async () => {
    const res = await request(app).get('/health');

    expect(res.status).toBe(200);
    expect(res.body).toMatchObject({ status: 'ok', version: 'test-sha' });
    expect(res.body.uptimeSeconds).toBeTypeOf('number');
    expect(new Date(res.body.timestamp).toISOString()).toBe(res.body.timestamp);
    expect(res.headers['x-powered-by']).toBeUndefined();
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
