import { describe, expect, it } from 'vitest';
import { ValidateQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { buildAccessRuntime, buildEventDeduplication } from '../../src/main/access-composition-root.js';
import {
  API_CONNECTIONS,
  WORKER_CONNECTIONS,
  apiConnectionTotal,
  workerConnectionTotal,
} from '../../src/main/config/connection-budget.js';
import { loadEnv } from '../../src/main/config/env.js';
import { FixedClock, NOW, SequentialIds } from '../support/terminal-fakes.js';

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
    const access = buildAccessRuntime(env, deps, API_CONNECTIONS.access);
    try {
      expect(access && Object.keys(access).sort()).toEqual(['commands', 'decide', 'decider', 'pool', 'repository']);
      expect(access?.pool.options.max).toBe(API_CONNECTIONS.access.max);
      expect(access?.pool.options.application_name).toBe(API_CONNECTIONS.access.applicationName);
    } finally {
      await access?.pool.end();
    }
  });

  it('a deduplicacao e montada a parte, so com o orcamento do worker', async () => {
    const dedup = buildEventDeduplication(env, WORKER_CONNECTIONS.events);
    try {
      expect(dedup?.pool.options.max).toBe(WORKER_CONNECTIONS.events.max);
      expect(dedup?.pool.options.application_name).toBe(WORKER_CONNECTIONS.events.applicationName);
    } finally {
      await dedup?.pool.end();
    }
  });
});
