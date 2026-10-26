import { describe, expect, it } from 'vitest';
import { InvalidEnvError, loadEnv } from '../../src/main/config/env.js';

describe('loadEnv', () => {
  it('aplica defaults quando nada e informado', () => {
    expect(loadEnv({})).toEqual({
      NODE_ENV: 'development',
      PORT: 3000,
      LOG_LEVEL: 'info',
      MQTT_URL: 'mqtt://localhost:1884',
      SIM_TERMINAL_ID: 'terminal-01',
      SIM_NFC_UID: '04A1B2C3',
      JWT_SECRET: 'dev-only-secret-nao-use-em-producao-32',
      JWT_TTL_SECONDS: 3600,
    });
  });

  it('le as variaveis MQTT e trata credenciais vazias como ausentes', () => {
    const env = loadEnv({
      MQTT_URL: 'mqtts://broker.example.com:8883',
      MQTT_USERNAME: 'abp4',
      MQTT_PASSWORD: '',
    });

    expect(env.MQTT_URL).toBe('mqtts://broker.example.com:8883');
    expect(env.MQTT_USERNAME).toBe('abp4');
    expect(env.MQTT_PASSWORD).toBeUndefined();
  });

  it('converte PORT e trata APP_VERSION vazia como ausente', () => {
    const env = loadEnv({
      NODE_ENV: 'production',
      PORT: '8080',
      APP_VERSION: '',
      JWT_SECRET: 'segredo-de-producao-com-32-caracteres',
    });

    expect(env.PORT).toBe(8080);
    expect(env.APP_VERSION).toBeUndefined();
  });

  it('aceita DATABASE_URL postgres e trata vazia como ausente', () => {
    const url = 'postgresql://user:pass@ep-x-pooler.neon.tech/db?sslmode=require';

    expect(loadEnv({ DATABASE_URL: url }).DATABASE_URL).toBe(url);
    expect(loadEnv({ DATABASE_URL: '' }).DATABASE_URL).toBeUndefined();
  });

  it('trata RENDER_EXTERNAL_URL vazia como ausente e valida a URL', () => {
    expect(loadEnv({ RENDER_EXTERNAL_URL: '' }).RENDER_EXTERNAL_URL).toBeUndefined();
    expect(loadEnv({ RENDER_EXTERNAL_URL: 'https://abp4.onrender.com' }).RENDER_EXTERNAL_URL).toBe(
      'https://abp4.onrender.com',
    );
    expect(() => loadEnv({ RENDER_EXTERNAL_URL: 'nao-e-url' })).toThrow('RENDER_EXTERNAL_URL');
  });

  it('retorna objeto congelado', () => {
    expect(Object.isFrozen(loadEnv({}))).toBe(true);
  });

  it.each([
    ['PORT nao numerica', { PORT: 'abc' }, 'PORT'],
    ['PORT fora da faixa', { PORT: '70000' }, 'PORT'],
    ['NODE_ENV desconhecido', { NODE_ENV: 'staging' }, 'NODE_ENV'],
    ['LOG_LEVEL desconhecido', { LOG_LEVEL: 'verbose' }, 'LOG_LEVEL'],
    ['MQTT_URL sem esquema mqtt', { MQTT_URL: 'http://localhost:1884' }, 'MQTT_URL'],
    ['SIM_TERMINAL_ID invalido', { SIM_TERMINAL_ID: 'Terminal 01' }, 'SIM_TERMINAL_ID'],
    ['SIM_NFC_UID nao hexadecimal', { SIM_NFC_UID: 'xyz' }, 'SIM_NFC_UID'],
    ['DATABASE_URL fora do padrao postgres', { DATABASE_URL: 'mysql://x' }, 'DATABASE_URL'],
    ['RENDER_EXTERNAL_URL invalida', { RENDER_EXTERNAL_URL: 'ftp://x' }, 'RENDER_EXTERNAL_URL'],
  ])('falha no boot com %s, citando a variavel', (_caso, source, variavel) => {
    expect(() => loadEnv(source)).toThrow(InvalidEnvError);
    expect(() => loadEnv(source)).toThrow(variavel);
  });
});
