import { describe, expect, it } from 'vitest';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';

describe('composicao em producao', () => {
  it('recusa subir a API com o JWT_SECRET de exemplo', () => {
    const env = loadEnv({ NODE_ENV: 'production', LOG_LEVEL: 'silent' });

    expect(() => buildContainer(env)).toThrow('JWT_SECRET');
  });

  it('aceita producao com segredo proprio', () => {
    const env = loadEnv({
      NODE_ENV: 'production',
      LOG_LEVEL: 'silent',
      JWT_SECRET: 'segredo-de-producao-com-32-caracteres',
    });

    expect(() => buildContainer(env)).not.toThrow();
  });
});
