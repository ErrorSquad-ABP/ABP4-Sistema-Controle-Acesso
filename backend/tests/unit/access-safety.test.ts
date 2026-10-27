import { describe, expect, it, vi } from 'vitest';
import { loadEnv } from '../../src/main/config/env.js';
import { resolveAccessDecider } from '../../src/main/config/access-decider.js';
import { AlwaysOpenAccessDecider } from '../../src/infrastructure/terminal/always-open-access-decider.js';
import { silentLogger } from '../support/terminal-fakes.js';

describe('DT-01: configuracao segura do consumidor', () => {
  it('usa modo real por padrao, inclusive no desenvolvimento', () => {
    expect(loadEnv({}).ACCESS_MODE).toBe('real');
  });

  it('recusa demo em producao e modos desconhecidos', () => {
    expect(() => loadEnv({ NODE_ENV: 'production', ACCESS_MODE: 'demo' })).toThrow('ACCESS_MODE');
    expect(() => loadEnv({ ACCESS_MODE: 'automatic' })).toThrow('ACCESS_MODE');
  });

  it.each(['production', 'development'] as const)('falha sem decisor real em %s', (NODE_ENV) => {
    expect(() => resolveAccessDecider(loadEnv({ NODE_ENV }), undefined, silentLogger)).toThrow('decisor real');
  });

  it('so escolhe o permissivo quando demo foi explicitamente selecionado', async () => {
    const logger = { ...silentLogger, warn: vi.fn() };
    const decider = resolveAccessDecider(loadEnv({ ACCESS_MODE: 'demo' }), undefined, logger);
    expect(decider).toBeInstanceOf(AlwaysOpenAccessDecider);
    expect(logger.warn).toHaveBeenCalledOnce();
  });

  it('producao usa o decisor recebido e rejeita o stub como decisor real', () => {
    const env = loadEnv({ NODE_ENV: 'production' });
    const real = { decide: vi.fn() };
    expect(resolveAccessDecider(env, real, silentLogger)).toBe(real);
    expect(() => resolveAccessDecider(env, new AlwaysOpenAccessDecider(), silentLogger)).toThrow('decisor real');
  });
});
