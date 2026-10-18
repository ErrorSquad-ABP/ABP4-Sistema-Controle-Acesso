import { describe, expect, it } from 'vitest';
import { CheckHealthUseCase } from '../../src/application/health/check-health.use-case.js';
import type { Clock } from '../../src/domain/ports/clock.js';

// Caso de uso testado sem Express nem infraestrutura: o port recebe um fake.
class FixedClock implements Clock {
  constructor(private readonly date: Date) {}
  now(): Date {
    return this.date;
  }
}

describe('CheckHealthUseCase', () => {
  const startedAt = new Date('2026-10-17T12:00:00.000Z');

  it('retorna status ok com versao, uptime e timestamp do clock', () => {
    const clock = new FixedClock(new Date('2026-10-17T12:01:30.900Z'));

    const result = new CheckHealthUseCase(clock, startedAt, '1.2.3').execute();

    expect(result).toEqual({
      status: 'ok',
      version: '1.2.3',
      uptimeSeconds: 90,
      timestamp: '2026-10-17T12:01:30.900Z',
    });
  });

  it('nunca reporta uptime negativo se o relogio voltar', () => {
    const clock = new FixedClock(new Date('2026-10-17T11:59:00.000Z'));

    expect(new CheckHealthUseCase(clock, startedAt, 'dev').execute().uptimeSeconds).toBe(0);
  });
});
