import { randomUUID } from 'node:crypto';
import { setTimeout as delay } from 'node:timers/promises';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import { ValidateQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { PostgresAccessRepository } from '../../src/infrastructure/database/postgres-access-repository.js';
import { hashCredential } from '../../src/shared/credential-hash.js';
import { FixedClock } from '../support/terminal-fakes.js';

const connectionString = process.env.DATABASE_URL;
const pool = connectionString
  ? new pg.Pool({ connectionString, max: 6, options: '-c timezone=UTC' })
  : null;

const TERMINAL_PREFIX = 'terminal-lock-';
const UID_PREFIX = 'LOCKTEST';

// Sem banco local o teste e pulado; no CI o Postgres do job sempre existe.
describe.skipIf(!pool)('DT-17: candidata que expira durante a espera do lock', () => {
  afterAll(async () => {
    await pool?.end();
  });

  async function seed(options: { secondAuthorization: boolean }) {
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

    // A vence em 1 s; B, em 1 h. A vem primeiro na ordem de escolha.
    const first = randomUUID();
    await pool!.query(
      `INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","usedCount","updatedAt")
       VALUES ($1,$2,$3,now() - interval '1 hour',$4,1,0,now())`,
      [first, userId, locationId, new Date(now.getTime() + 1_000).toISOString()],
    );
    const second = options.secondAuthorization ? randomUUID() : null;
    if (second) {
      await pool!.query(
        `INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","usedCount","updatedAt")
         VALUES ($1,$2,$3,now() - interval '1 hour',$4,1,0,now())`,
        [second, userId, locationId, new Date(now.getTime() + 3_600_000).toISOString()],
      );
    }

    const repository = new PostgresAccessRepository(pool!);
    const ids = { uuid: () => randomUUID(), token: () => 'x' };
    const decide = new DecideAccessUseCase(
      repository,
      clock,
      new ValidateQrCredentialUseCase(clock, new HmacQrTokenSigner('a'.repeat(64))),
      ids,
    );
    return { userId, locationId, clock, decide, first, second, terminalId, uid };
  }

  /**
   * Segura o lock da primeira candidata, dispara a decisao e so libera depois de
   * avancar o relogio: a primeira autorizacao vence na espera, como em producao
   * quando duas instancias disputam o mesmo usuario.
   */
  async function decideWhileFirstIsLocked(
    clock: FixedClock,
    run: () => Promise<{ decision: string; reason: string | null; authorizationId: string | null }>,
    firstId: string,
    advanceMs: number,
  ) {
    const locker = await pool!.connect();
    try {
      await locker.query('BEGIN');
      await locker.query('SELECT 1 FROM "Authorization" WHERE id=$1 FOR UPDATE', [firstId]);
      const pending = run();
      await delay(300);
      clock.date = new Date(clock.date.getTime() + advanceMs);
      await locker.query('COMMIT');
      return await pending;
    } finally {
      locker.release();
    }
  }

  it('libera pela proxima autorizacao utilizavel em vez de negar', async () => {
    const { clock, decide, first, second, terminalId, uid } = await seed({ secondAuthorization: true });

    const event = await decideWhileFirstIsLocked(
      clock,
      () => decide.execute({ id: randomUUID(), terminalId, method: 'NFC', uid }),
      first,
      2_000,
    );

    expect(event).toMatchObject({ decision: 'GRANTED', authorizationId: second });
    expect(
      (await pool!.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [first])).rows[0].usedCount,
    ).toBe(0);
    expect(
      (await pool!.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [second])).rows[0].usedCount,
    ).toBe(1);
  });

  it('sem outra candidata, nega por validade', async () => {
    const { clock, decide, first, terminalId, uid } = await seed({ secondAuthorization: false });

    const event = await decideWhileFirstIsLocked(
      clock,
      () => decide.execute({ id: randomUUID(), terminalId, method: 'NFC', uid }),
      first,
      2_000,
    );

    expect(event).toMatchObject({ decision: 'DENIED', reason: 'AUTHORIZATION_EXPIRED', authorizationId: null });
    expect(
      (await pool!.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [first])).rows[0].usedCount,
    ).toBe(0);
  });
});
