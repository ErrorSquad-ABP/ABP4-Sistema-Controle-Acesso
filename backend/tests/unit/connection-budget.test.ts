import { describe, expect, it, vi } from 'vitest';
import { ValidateQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import { prismaPoolOptions } from '../../src/infrastructure/database/prisma-client.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { buildAccessRuntime, buildEventDeduplication } from '../../src/main/access-composition-root.js';
import {
  API_CONNECTIONS,
  POOL_CONNECTION_TIMEOUT_MS,
  POOL_QUERY_TIMEOUT_MS,
  WORKER_CONNECTIONS,
  apiConnectionTotal,
  workerConnectionTotal,
} from '../../src/main/config/connection-budget.js';
import { loadEnv } from '../../src/main/config/env.js';
import { FixedClock, NOW, SequentialIds, silentLogger } from '../support/terminal-fakes.js';

// pg.Pool so conecta na primeira consulta: montar os pools aqui nao abre conexao.
const env = loadEnv({
  QR_TOKEN_SECRET: 'a'.repeat(64),
  LOG_LEVEL: 'silent',
  DATABASE_URL: 'postgresql://abp4:abp4@127.0.0.1:1/abp4',
});
const clock = new FixedClock(NOW);
const deps = {
  clock,
  ids: new SequentialIds(),
  qr: new ValidateQrCredentialUseCase(clock, new HmacQrTokenSigner('a'.repeat(64))),
};

describe('DT-14: orcamento de conexoes', () => {
  it('fecha em 7 conexoes por instancia da API e 7 no worker', () => {
    expect(apiConnectionTotal()).toBe(7);
    expect(workerConnectionTotal()).toBe(7);
  });

  it('cada fonte tem nome proprio para medir no pg_stat_activity', () => {
    const names = [...Object.values(API_CONNECTIONS), ...Object.values(WORKER_CONNECTIONS)]
      .map((pool) => pool.applicationName);
    expect(new Set(names).size).toBe(names.length);
  });

  it('o runtime de acesso nao cria a deduplicacao MQTT e respeita o limite pedido', async () => {
    const access = buildAccessRuntime(env, deps, API_CONNECTIONS.access, silentLogger);
    try {
      expect(access && Object.keys(access).sort()).toEqual(['commands', 'decide', 'decider', 'pool', 'repository']);
      expect(access?.pool.options.max).toBe(API_CONNECTIONS.access.max);
      expect(access?.pool.options.application_name).toBe(API_CONNECTIONS.access.applicationName);
    } finally {
      await access?.pool.end();
    }
  });

  it('a deduplicacao e montada a parte, so com o orcamento do worker', async () => {
    const dedup = buildEventDeduplication(env, WORKER_CONNECTIONS.events, silentLogger);
    try {
      expect(dedup?.pool.options.max).toBe(WORKER_CONNECTIONS.events.max);
      expect(dedup?.pool.options.application_name).toBe(WORKER_CONNECTIONS.events.applicationName);
    } finally {
      await dedup?.pool.end();
    }
  });

  it('todo pool limita a espera pela resposta da consulta, alem da conexao livre', async () => {
    const access = buildAccessRuntime(env, deps, API_CONNECTIONS.access, silentLogger);
    const dedup = buildEventDeduplication(env, WORKER_CONNECTIONS.events, silentLogger);
    try {
      for (const pool of [access?.pool, dedup?.pool]) {
        expect(pool?.options.connectionTimeoutMillis).toBe(POOL_CONNECTION_TIMEOUT_MS);
        expect(pool?.options.query_timeout).toBe(POOL_QUERY_TIMEOUT_MS);
      }
    } finally {
      await access?.pool.end();
      await dedup?.pool.end();
    }
  });

  it('o pool do Prisma (driver adapter) recebe o mesmo teto de consulta', () => {
    const options = prismaPoolOptions('postgresql://abp4:abp4@127.0.0.1:1/abp4', {
      ...API_CONNECTIONS.prisma,
      connectionTimeoutMillis: POOL_CONNECTION_TIMEOUT_MS,
      queryTimeoutMillis: POOL_QUERY_TIMEOUT_MS,
    });
    expect(options).toMatchObject({
      max: API_CONNECTIONS.prisma.max,
      application_name: API_CONNECTIONS.prisma.applicationName,
      connectionTimeoutMillis: POOL_CONNECTION_TIMEOUT_MS,
      query_timeout: POOL_QUERY_TIMEOUT_MS,
    });
    // Startup GUC: o pooler do Neon recusa `statement_timeout` como parametro de
    // startup ("unsupported startup parameter"), entao ele nao entra na conexao.
    expect(options).not.toHaveProperty('statement_timeout');
  });
});

describe('DT-16: falhas das pools no log', () => {
  it('conexao ociosa que cai vira warn com a fonte e sem a senha', async () => {
    const logger = { ...silentLogger, warn: vi.fn() };
    const access = buildAccessRuntime(env, deps, WORKER_CONNECTIONS.access, logger);
    const dedup = buildEventDeduplication(env, WORKER_CONNECTIONS.events, logger);
    try {
      const failure = Object.assign(new Error('conexao perdida com postgresql://abp4:segredo@db.neon.tech/abp4'), {
        code: 'ECONNRESET',
      });
      expect(() => access?.pool.emit('error', failure)).not.toThrow();
      dedup?.pool.emit('error', failure);

      expect(logger.warn).toHaveBeenCalledWith('falha em conexao ociosa do postgres', {
        pool: WORKER_CONNECTIONS.access.applicationName,
        code: 'ECONNRESET',
        error: 'conexao perdida com postgresql://***',
      });
      expect(logger.warn).toHaveBeenCalledWith('falha em conexao ociosa do postgres', expect.objectContaining({
        pool: WORKER_CONNECTIONS.events.applicationName,
      }));
      expect(JSON.stringify(logger.warn.mock.calls)).not.toContain('segredo');
    } finally {
      await access?.pool.end();
      await dedup?.pool.end();
    }
  });
});
