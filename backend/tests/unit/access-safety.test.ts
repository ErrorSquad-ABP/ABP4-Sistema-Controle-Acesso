import { describe, expect, it, vi } from 'vitest';
import { loadEnv } from '../../src/main/config/env.js';
import { resolveAccessDecider } from '../../src/main/config/access-decider.js';
import { AlwaysOpenAccessDecider } from '../../src/infrastructure/terminal/always-open-access-decider.js';
import { silentLogger } from '../support/terminal-fakes.js';

const configured = (env: NodeJS.ProcessEnv = {}) => loadEnv({ QR_TOKEN_SECRET: 'a'.repeat(64), ...env });

describe('DT-01: configuracao segura do consumidor', () => {
  it('usa modo real por padrao, inclusive no desenvolvimento', () => {
    expect(configured().ACCESS_MODE).toBe('real');
  });

  it('recusa demo em producao e modos desconhecidos', () => {
    expect(() => configured({ NODE_ENV: 'production', ACCESS_MODE: 'demo' })).toThrow('ACCESS_MODE');
    expect(() => configured({ ACCESS_MODE: 'automatic' })).toThrow('ACCESS_MODE');
  });

  it.each(['production', 'development'] as const)('falha sem decisor real em %s', (NODE_ENV) => {
    expect(() => resolveAccessDecider(configured({ NODE_ENV }), undefined, silentLogger)).toThrow(
      'decisor real',
    );
  });

  it('so escolhe o permissivo quando demo foi explicitamente selecionado', async () => {
    const logger = { ...silentLogger, warn: vi.fn() };
    const decider = resolveAccessDecider(configured({ ACCESS_MODE: 'demo' }), undefined, logger);
    expect(decider).toBeInstanceOf(AlwaysOpenAccessDecider);
    expect(logger.warn).toHaveBeenCalledOnce();
    expect(await decider.decide({
      v: 1, messageId: '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10', terminalId: 'terminal-01',
      timestamp: '2026-10-19T19:30:00.000Z', type: 'nfc_read', uid: '04A1B2C3',
    })).toMatchObject({ action: 'open', decidedAt: expect.any(Date) });
  });

  it('producao usa o decisor recebido e rejeita o stub como decisor real', () => {
    const env = configured({ NODE_ENV: 'production' });
    const real = { decide: vi.fn() };
    expect(resolveAccessDecider(env, real, silentLogger)).toBe(real);
    expect(() => resolveAccessDecider(env, new AlwaysOpenAccessDecider(), silentLogger)).toThrow(
      'decisor real',
    );
  });
});
