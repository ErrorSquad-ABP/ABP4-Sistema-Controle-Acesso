import { describe, expect, it } from 'vitest';
import { InvalidEnvError, loadEnv } from '../../src/main/config/env.js';

describe('loadEnv', () => {
  it('aplica defaults quando nada e informado', () => {
    expect(loadEnv({})).toEqual({ NODE_ENV: 'development', PORT: 3000, LOG_LEVEL: 'info' });
  });

  it('converte PORT e trata APP_VERSION vazia como ausente', () => {
    const env = loadEnv({ NODE_ENV: 'production', PORT: '8080', APP_VERSION: '' });

    expect(env.PORT).toBe(8080);
    expect(env.APP_VERSION).toBeUndefined();
  });

  it('retorna objeto congelado', () => {
    expect(Object.isFrozen(loadEnv({}))).toBe(true);
  });

  it.each([
    ['PORT nao numerica', { PORT: 'abc' }, 'PORT'],
    ['PORT fora da faixa', { PORT: '70000' }, 'PORT'],
    ['NODE_ENV desconhecido', { NODE_ENV: 'staging' }, 'NODE_ENV'],
    ['LOG_LEVEL desconhecido', { LOG_LEVEL: 'verbose' }, 'LOG_LEVEL'],
  ])('falha no boot com %s, citando a variavel', (_caso, source, variavel) => {
    expect(() => loadEnv(source)).toThrow(InvalidEnvError);
    expect(() => loadEnv(source)).toThrow(variavel);
  });
});
