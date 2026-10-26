import { describe, expect, it } from 'vitest';
import { InvalidEnvError, loadEnv } from '../../src/main/config/env.js';

const SECRET = 'a'.repeat(64);
const configured = (env: NodeJS.ProcessEnv = {}) => loadEnv({ QR_TOKEN_SECRET: SECRET, ...env });

describe('loadEnv', () => {
  it('aplica defaults quando nada e informado', () => {
    expect(configured()).toEqual({
      NODE_ENV: 'development',
      PORT: 3000,
      LOG_LEVEL: 'info',
      QR_TOKEN_SECRET: SECRET,
      MQTT_URL: 'mqtt://localhost:1884',
      SIM_TERMINAL_ID: 'terminal-01',
      SIM_NFC_UID: '04A1B2C3',
    });
  });

  it('le as variaveis MQTT e trata credenciais vazias como ausentes', () => {
    const env = configured({
      MQTT_URL: 'mqtts://broker.example.com:8883',
      MQTT_USERNAME: 'abp4',
      MQTT_PASSWORD: '',
    });

    expect(env.MQTT_URL).toBe('mqtts://broker.example.com:8883');
    expect(env.MQTT_USERNAME).toBe('abp4');
    expect(env.MQTT_PASSWORD).toBeUndefined();
  });

  it('converte PORT e trata APP_VERSION vazia como ausente', () => {
    const env = configured({ NODE_ENV: 'production', PORT: '8080', APP_VERSION: '' });

    expect(env.PORT).toBe(8080);
    expect(env.APP_VERSION).toBeUndefined();
  });

  it('aceita DATABASE_URL postgres e trata vazia como ausente', () => {
    const url = 'postgresql://user:pass@ep-x-pooler.neon.tech/db?sslmode=require';

    expect(configured({ DATABASE_URL: url }).DATABASE_URL).toBe(url);
    expect(configured({ DATABASE_URL: '' }).DATABASE_URL).toBeUndefined();
  });

  it('retorna objeto congelado', () => {
    expect(Object.isFrozen(configured())).toBe(true);
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
    ['QR_TOKEN_SECRET curto', { QR_TOKEN_SECRET: 'a'.repeat(63) }, 'QR_TOKEN_SECRET'],
    ['QR_TOKEN_SECRET nao hexadecimal', { QR_TOKEN_SECRET: 'z'.repeat(64) }, 'QR_TOKEN_SECRET'],
  ])('falha no boot com %s, citando a variavel', (_caso, source, variavel) => {
    expect(() => loadEnv({ QR_TOKEN_SECRET: SECRET, ...source })).toThrow(InvalidEnvError);
    expect(() => loadEnv({ QR_TOKEN_SECRET: SECRET, ...source })).toThrow(variavel);
  });

  it('exige QR_TOKEN_SECRET sem valor padrão', () => {
    expect(() => loadEnv({})).toThrow(InvalidEnvError);
    expect(() => loadEnv({})).toThrow('QR_TOKEN_SECRET');
  });
});
