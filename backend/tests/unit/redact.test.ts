import { describe, expect, it } from 'vitest';
import { maskUid, redactConnectionString } from '../../src/shared/redact.js';

describe('redact', () => {
  it('mascara o UID NFC', () => {
    expect(maskUid('04A1B2C3')).toBe('****B2C3');
    expect(maskUid('04A1')).toBe('****');
  });

  it('tira usuario, senha e host da URL do banco (DT-16)', () => {
    expect(redactConnectionString('falha em postgres://u:p@h:5432/db?sslmode=require: timeout')).toBe(
      'falha em postgresql://*** timeout',
    );
    expect(redactConnectionString('POSTGRESQL://abp4:segredo@ep-x.neon.tech/abp4')).toBe('postgresql://***');
    expect(redactConnectionString('Connection terminated unexpectedly')).toBe('Connection terminated unexpectedly');
  });
});
