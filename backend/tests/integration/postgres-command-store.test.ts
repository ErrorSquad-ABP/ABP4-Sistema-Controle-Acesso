import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { PublishCommandUseCase } from '../../src/application/terminal/publish-command.use-case.js';
import { PurgeExpiredCommandsUseCase } from '../../src/application/terminal/purge-expired-commands.use-case.js';
import { COMMAND_RETENTION_MS } from '../../src/domain/terminal/command-retention.js';
import { COMMAND_TTL_MS, CONTRACT_VERSION } from '../../src/domain/terminal/messages.js';
import { PostgresCommandStore } from '../../src/infrastructure/database/postgres-command-store.js';
import { FixedClock, RecordingBus } from '../support/terminal-fakes.js';

const connectionString = process.env.DATABASE_URL;
const pool = connectionString
  ? new pg.Pool({ connectionString, max: 2, options: '-c timezone=UTC' })
  : null;
const clock = new FixedClock(new Date());

const DAY_MS = 24 * 60 * 60_000;

// Sem banco local o teste e pulado; no CI o Postgres do job sempre existe.
describe.skipIf(!pool)('PostgresCommandStore (DT-18)', () => {
  const store = pool ? new PostgresCommandStore(pool) : null;

  async function insertCommand(expiresAt: Date, commandId = randomUUID()) {
    await pool!.query(
      `INSERT INTO "TerminalCommand" ("commandId","requestId","terminalId",payload,"expiresAt")
       VALUES ($1,$2,$3,$4,$5)`,
      [commandId, randomUUID(), 'terminal-01', JSON.stringify({ commandId }), expiresAt],
    );
    return commandId;
  }

  async function remaining(commandIds: string[]) {
    const result = await pool!.query('SELECT count(*)::int AS total FROM "TerminalCommand" WHERE "commandId" = ANY($1)', [
      commandIds,
    ]);
    return result.rows[0].total as number;
  }

  afterAll(async () => {
    await pool?.end();
  });

  it('apaga so o que passou da retencao, em lotes', async () => {
    const now = clock.now();
    const antigos = [
      await insertCommand(new Date(now.getTime() - 30 * DAY_MS)),
      await insertCommand(new Date(now.getTime() - 10 * DAY_MS)),
      await insertCommand(new Date(now.getTime() - 8 * DAY_MS)),
    ];
    const preservados = [
      await insertCommand(new Date(now.getTime() - 1 * DAY_MS)), // ACK tardio ainda vale
      await insertCommand(new Date(now.getTime() - COMMAND_TTL_MS)), // recem-expirado
      await insertCommand(new Date(now.getTime() + COMMAND_TTL_MS)), // vigente
    ];
    const cutoff = new Date(now.getTime() - COMMAND_RETENTION_MS);

    expect(await store!.purgeExpired(cutoff, 2)).toBe(2);
    expect(await remaining(antigos)).toBe(1);
    expect(await remaining(preservados)).toBe(3);

    expect(await store!.purgeExpired(cutoff, 2)).toBe(1);
    expect(await remaining(antigos)).toBe(0);
    expect(await remaining(preservados)).toBe(3);
  });

  it('ACK tardio dentro da retencao ainda correlaciona; comando apagado vira desconhecido', async () => {
    const now = clock.now();
    const tardio = randomUUID();
    await insertCommand(new Date(now.getTime() - 2 * DAY_MS), tardio);

    expect(
      await store!.acknowledge({
        v: CONTRACT_VERSION,
        messageId: randomUUID(),
        terminalId: 'terminal-01',
        timestamp: now.toISOString(),
        commandId: tardio,
        status: 'executed',
      }),
    ).toMatchObject({ status: 'correlated' });

    const apagado = await insertCommand(new Date(now.getTime() - 30 * DAY_MS));
    await store!.purgeExpired(new Date(now.getTime() - COMMAND_RETENTION_MS), 500);

    expect(
      await store!.acknowledge({
        v: CONTRACT_VERSION,
        messageId: randomUUID(),
        terminalId: 'terminal-01',
        timestamp: now.toISOString(),
        commandId: apagado,
        status: 'executed',
      }),
    ).toEqual({ status: 'unknown' });
  });

  it('repetir a tentativa depois do expurgo nao republica nem reabre a porta', async () => {
    const occurredAt = new Date(clock.now().getTime() - 8 * DAY_MS);
    const requestId = randomUUID();
    const commandId = randomUUID();
    await pool!.query(
      `INSERT INTO "AccessEvent" (id,method,decision,reason,"occurredAt")
       VALUES ($1,'QR','GRANTED',NULL,$2)`,
      [requestId, occurredAt],
    );
    await pool!.query(
      `INSERT INTO "TerminalCommand" ("commandId","requestId","terminalId",payload,"expiresAt")
       VALUES ($1,$2,$3,$4,$5)`,
      [commandId, requestId, 'terminal-01', JSON.stringify({ commandId }), new Date(occurredAt.getTime() + COMMAND_TTL_MS)],
    );

    expect(await store!.purgeExpired(new Date(clock.now().getTime() - COMMAND_RETENTION_MS), 500)).toBeGreaterThan(0);
    expect(await store!.findByRequestId(requestId)).toBeUndefined();

    const bus = new RecordingBus();
    const publish = new PublishCommandUseCase(
      store!,
      bus,
      clock,
      { uuid: () => randomUUID(), token: () => 'x' },
    );
    const result = await publish.execute({
      requestId,
      terminalId: 'terminal-01',
      action: 'open',
      reason: 'authorized',
      decidedAt: occurredAt,
    });

    expect(result.published).toBe(false);
    expect(bus.published).toHaveLength(0);
    const event = await pool!.query('SELECT decision FROM "AccessEvent" WHERE id=$1', [requestId]);
    expect(event.rows).toEqual([{ decision: 'GRANTED' }]);
  });

  it('o expurgo periodico remove o backlog antigo em lotes limitados', async () => {
    const now = clock.now();
    for (let i = 0; i < 3; i += 1) {
      await insertCommand(new Date(now.getTime() - (40 + i) * DAY_MS));
    }

    const purge = new PurgeExpiredCommandsUseCase(store!, clock);
    expect(await purge.execute()).toBeGreaterThanOrEqual(3);
  });
});
