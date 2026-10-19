import { describe, expect, it } from 'vitest';
import { CheckHealthUseCase } from '../../src/application/health/check-health.use-case.js';
import type { Clock } from '../../src/domain/ports/clock.js';
import type { DatabaseProbe } from '../../src/domain/ports/database-probe.js';
import { createLogger } from '../../src/shared/logger.js';

// Caso de uso testado sem Express nem infraestrutura: os ports recebem fakes.
class FixedClock implements Clock {
  constructor(public date: Date) {}
  now(): Date {
    return this.date;
  }
}

class FakeDatabase implements DatabaseProbe {
  constructor(private readonly error?: Error) {}
  ping(): Promise<void> {
    return this.error ? Promise.reject(this.error) : Promise.resolve();
  }
}

const logger = createLogger('silent');

describe('CheckHealthUseCase', () => {
  const startedAt = new Date('2026-10-17T12:00:00.000Z');

  it('retorna status ok com versao, uptime, timestamp do clock e banco ok', async () => {
    const clock = new FixedClock(new Date('2026-10-17T12:01:30.900Z'));

    const result = await new CheckHealthUseCase(
      clock,
      startedAt,
      '1.2.3',
      new FakeDatabase(),
      logger,
    ).execute();

    expect(result).toEqual({
      status: 'ok',
      version: '1.2.3',
      uptimeSeconds: 90,
      timestamp: '2026-10-17T12:01:30.900Z',
      database: 'ok',
    });
  });

  it('nunca reporta uptime negativo se o relogio voltar', async () => {
    const clock = new FixedClock(new Date('2026-10-17T11:59:00.000Z'));

    const result = await new CheckHealthUseCase(clock, startedAt, 'dev', undefined, logger).execute();

    expect(result.uptimeSeconds).toBe(0);
  });

  it('informa not_configured e segue ok quando nao ha banco configurado', async () => {
    const clock = new FixedClock(startedAt);

    const result = await new CheckHealthUseCase(clock, startedAt, 'dev', undefined, logger).execute();

    expect(result).toMatchObject({ status: 'ok', database: 'not_configured' });
  });

  it('reaproveita o resultado do banco por 5 s e consulta de novo depois', async () => {
    let pings = 0;
    const database: DatabaseProbe = {
      ping: () => {
        pings += 1;
        return Promise.resolve();
      },
    };
    const clock = new FixedClock(startedAt);
    const useCase = new CheckHealthUseCase(clock, startedAt, 'dev', database, logger);

    await useCase.execute();
    await useCase.execute();
    expect(pings).toBe(1);

    clock.date = new Date(startedAt.getTime() + 5000);
    await useCase.execute();
    expect(pings).toBe(2);
  });

  it('informa status error e database unavailable quando o banco falha', async () => {
    const clock = new FixedClock(startedAt);
    const database = new FakeDatabase(new Error('connect ECONNREFUSED 10.0.0.1:5432'));

    const result = await new CheckHealthUseCase(clock, startedAt, 'dev', database, logger).execute();

    expect(result).toMatchObject({ status: 'error', database: 'unavailable' });
    expect(JSON.stringify(result)).not.toContain('ECONNREFUSED');
  });
});
