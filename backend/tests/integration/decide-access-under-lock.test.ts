import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import { ValidateQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import { PostgresAccessRepository } from '../../src/infrastructure/database/postgres-access-repository.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { hashCredential } from '../../src/shared/credential-hash.js';
import { FixedClock } from '../support/terminal-fakes.js';

const connectionString = process.env.DATABASE_URL;
const pool = connectionString
  ? new pg.Pool({ connectionString, max: 6, options: '-c timezone=UTC' })
  : null;

const TERMINAL_PREFIX = 'terminal-lock-';
const UID_PREFIX = 'LOCKTEST';

/** Espera a sessao da decisao ficar bloqueada pelo `blockerPid`: sem isso o teste nao prova nada. */
async function waitForBlockedSession(blockerPid: number, timeoutMs = 10_000): Promise<void> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const waiting = await pool!.query<{ total: number }>(
      `SELECT count(*)::int AS total FROM pg_stat_activity WHERE $1::int = ANY(pg_blocking_pids(pid))`,
      [blockerPid],
    );
    if (waiting.rows[0]!.total > 0) return;
    await delay(20);
  }
  throw new Error('a decisao nao chegou a esperar o lock do cenario');
}

// Sem banco local o teste e pulado; no CI o Postgres do job sempre existe.
describe.skipIf(!pool)('DT-17: candidata que muda de estado durante a espera do lock', () => {
  afterAll(async () => {
    await pool?.end();
  });

  interface SeedOptions {
    /** Autorizacao que vence no instante do lock e bloqueia a decisao. */
    firstEndsInMs: number;
    /** Autorizacao que ja esta valida agora (vence em 1 h). */
    secondUsable?: boolean;
    /** Autorizacao que so comeca a valer durante a espera. */
    secondStartsInMs?: number;
    /** Historico cancelado mais antigo que tudo (define o motivo da negativa). */
    canceledBeforeAll?: boolean;
  }

  async function seed(options: SeedOptions) {
    const userId = randomUUID();
    const locationId = randomUUID();
    const clock = new FixedClock(new Date());
    const now = clock.now();
    const suffix = userId.slice(0, 8);
    const terminalId = `${TERMINAL_PREFIX}${suffix}`;
    const uid = `${UID_PREFIX}${suffix}`;

    await pool!.query(
      `INSERT INTO "User" (id,name,email,"passwordHash",role,"updatedAt")
       VALUES ($1,'Maria',$2,'scrypt$x$y$z','RESIDENT',now())`,
      [userId, `${userId}@abp4.local`],
    );
    await pool!.query(
      `INSERT INTO "AccessLocation" (id,name,latitude,longitude,"radiusMeters","updatedAt")
       VALUES ($1,'Recepcao',-23,-45,100,now())`,
      [locationId],
    );
    await pool!.query(
      `INSERT INTO "Terminal" (id,"locationId","updatedAt") VALUES ($1,$2,now())`,
      [terminalId, locationId],
    );
    await pool!.query(
      `INSERT INTO "Credential" (id,"userId",type,"valueHash","updatedAt")
       VALUES ($1,$2,'NFC',$3,now())`,
      [randomUUID(), userId, hashCredential(uid.toUpperCase())],
    );

    const insert = async (startOffsetMs: number, endOffsetMs: number, canceled = false) => {
      const id = randomUUID();
      await pool!.query(
        `INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","usedCount","canceledAt","updatedAt")
         VALUES ($1,$2,$3,$4,$5,1,0,$6,now())`,
        [
          id,
          userId,
          locationId,
          new Date(now.getTime() + startOffsetMs).toISOString(),
          new Date(now.getTime() + endOffsetMs).toISOString(),
          canceled ? now.toISOString() : null,
        ],
      );
      return id;
    };

    const history = options.canceledBeforeAll ? await insert(-72 * 3_600_000, -71 * 3_600_000, true) : null;
    // `first` e a primeira da ordem de escolha e sera a linha travada pelo teste.
    const first = await insert(-3_600_000, options.firstEndsInMs);
    const second =
      options.secondUsable
        ? await insert(-3_600_000, 3_600_000)
        : options.secondStartsInMs === undefined
          ? null
          : await insert(options.secondStartsInMs, 3_600_000);

    const decide = new DecideAccessUseCase(
      new PostgresAccessRepository(pool!),
      clock,
      new ValidateQrCredentialUseCase(clock, new HmacQrTokenSigner('a'.repeat(64))),
      { uuid: () => randomUUID(), token: () => 'x' },
    );
    return { userId, clock, decide, first, second, history, terminalId, uid };
  }

  /**
   * Segura o lock da primeira candidata, dispara a decisao e so libera depois de
   * confirmar (por `pg_blocking_pids`) que ela esta esperando e de avancar o relogio.
   */
  async function decideWhileFirstIsLocked(
    seedData: Awaited<ReturnType<typeof seed>>,
    advanceMs: number,
    mutation: 'lock' | 'exhaust' | 'cancel' = 'lock',
  ) {
    const { clock, decide, first, terminalId, uid } = seedData;
    const locker = await pool!.connect();
    try {
      const { rows } = await locker.query<{ pid: number }>('SELECT pg_backend_pid() AS pid');
      await locker.query('BEGIN');
      if (mutation === 'exhaust') {
        await locker.query('UPDATE "Authorization" SET "usedCount"="maxUses" WHERE id=$1', [first]);
      } else if (mutation === 'cancel') {
        await locker.query('UPDATE "Authorization" SET "canceledAt"=now() WHERE id=$1', [first]);
      } else {
        await locker.query('SELECT 1 FROM "Authorization" WHERE id=$1 FOR UPDATE', [first]);
      }
      const pending = decide.execute({ id: randomUUID(), terminalId, method: 'NFC', uid });
      await waitForBlockedSession(rows[0]!.pid);
      clock.date = new Date(clock.date.getTime() + advanceMs);
      await locker.query('COMMIT');
      return await pending;
    } finally {
      locker.release();
    }
  }

  async function usedCount(id: string): Promise<number> {
    return (await pool!.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [id])).rows[0].usedCount;
  }

  it('libera pela proxima autorizacao utilizavel em vez de negar', async () => {
    const seedData = await seed({ firstEndsInMs: 1_000, secondUsable: true });

    const event = await decideWhileFirstIsLocked(seedData, 2_000);

    expect(event).toMatchObject({ decision: 'GRANTED', authorizationId: seedData.second });
    expect(await usedCount(seedData.first)).toBe(0);
    expect(await usedCount(seedData.second!)).toBe(1);
  });

  it('libera pela autorizacao que comeca a valer durante a espera', async () => {
    const seedData = await seed({ firstEndsInMs: 1_000, secondStartsInMs: 1_000 });

    const event = await decideWhileFirstIsLocked(seedData, 2_000);

    expect(event).toMatchObject({ decision: 'GRANTED', authorizationId: seedData.second });
    expect(await usedCount(seedData.second!)).toBe(1);
  });

  it('sem nada utilizavel, nega por validade', async () => {
    const seedData = await seed({ firstEndsInMs: 1_000 });

    const event = await decideWhileFirstIsLocked(seedData, 2_000);

    expect(event).toMatchObject({ decision: 'DENIED', reason: 'AUTHORIZATION_EXPIRED', authorizationId: null });
    expect(await usedCount(seedData.first)).toBe(0);
  });

  it('mantem o motivo da primeira linha global quando nada serve', async () => {
    const seedData = await seed({ firstEndsInMs: 1_000, canceledBeforeAll: true });

    const event = await decideWhileFirstIsLocked(seedData, 2_000);

    expect(event).toMatchObject({ decision: 'DENIED', reason: 'AUTHORIZATION_CANCELED', authorizationId: null });
  });

  it('ignora a primeira quando ela e esgotada durante a espera e libera pela seguinte', async () => {
    const seedData = await seed({ firstEndsInMs: 600_000, secondUsable: true });

    const event = await decideWhileFirstIsLocked(seedData, 0, 'exhaust');

    expect(event).toMatchObject({ decision: 'GRANTED', authorizationId: seedData.second });
    expect(await usedCount(seedData.first)).toBe(1);
    expect(await usedCount(seedData.second!)).toBe(1);
  });

  it('ignora a primeira quando ela e cancelada durante a espera e libera pela seguinte', async () => {
    const seedData = await seed({ firstEndsInMs: 600_000, secondUsable: true });

    const event = await decideWhileFirstIsLocked(seedData, 0, 'cancel');

    expect(event).toMatchObject({ decision: 'GRANTED', authorizationId: seedData.second });
    expect(await usedCount(seedData.second!)).toBe(1);
  });
});
