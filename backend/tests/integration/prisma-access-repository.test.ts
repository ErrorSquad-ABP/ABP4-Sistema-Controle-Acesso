import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { decideAccess } from '../../src/domain/access/access-policy.js';
import type { AccessTransaction } from '../../src/domain/ports/access-repository.js';
import {
  AUTHORIZATION_CANDIDATES_SQL,
  PostgresAccessRepository,
} from '../../src/infrastructure/database/postgres-access-repository.js';

const connectionString = process.env.DATABASE_URL;
const pool = connectionString
  ? new pg.Pool({ connectionString, max: 6, options: '-c timezone=UTC' })
  : null;
const repository = pool ? new PostgresAccessRepository(pool) : null;
const now = new Date();

// Leitura completa como a decisao fazia antes da DT-17: referencia de equivalencia.
const LEGACY_SQL = `SELECT id,"userId","locationId","maxUses","usedCount",
  "startsAt" AT TIME ZONE 'UTC' AS "startsAt", "endsAt" AT TIME ZONE 'UTC' AS "endsAt",
  "canceledAt" AT TIME ZONE 'UTC' AS "canceledAt" FROM "Authorization"
  WHERE "userId"=$1 AND "locationId"=$2 ORDER BY "endsAt", id`;

// Sem banco local o teste e pulado; no CI o Postgres do job sempre existe.
describe.skipIf(!repository)('PostgresAccessRepository (DT-17)', () => {
  afterAll(async () => {
    await pool?.end();
  });

  async function seedPlace() {
    const userId = randomUUID();
    const locationId = randomUUID();
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
    return { userId, locationId };
  }

  /** Blocos de historico: cada bloco tem o seu proprio `endsAt` (ordem de escolha). */
  async function seedBlock(
    userId: string,
    locationId: string,
    total: number,
    options: { startDays: number; endDays: number; usedCount?: number; canceled?: boolean },
  ): Promise<string[]> {
    if (!total) return [];
    const inserted = await pool!.query<{ id: string }>(
      `INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","usedCount","canceledAt","updatedAt")
       SELECT gen_random_uuid(), $1, $2, now() - ($3 || ' days')::interval, now() - ($4 || ' days')::interval,
              1, $5, $6, now()
       FROM generate_series(1, $7) RETURNING id`,
      [userId, locationId, String(options.startDays), String(options.endDays), options.usedCount ?? 0,
       options.canceled ? now.toISOString() : null, total],
    );
    return inserted.rows.map((row) => row.id);
  }

  async function insertAvailable(userId: string, locationId: string, maxUses = 2) {
    const id = randomUUID();
    await pool!.query(
      `INSERT INTO "Authorization" (id,"userId","locationId","startsAt","endsAt","maxUses","usedCount","updatedAt")
       VALUES ($1,$2,$3,now() - interval '1 hour',$4,$5,0,now())`,
      [id, userId, locationId, new Date(now.getTime() + 3_600_000).toISOString(), maxUses],
    );
    return id;
  }

  function decision(authorizations: Awaited<ReturnType<AccessTransaction['findAuthorizations']>>, userId: string, locationId: string) {
    return decideAccess({
      terminal: {
        id: 'terminal-01',
        active: true,
        location: { id: locationId, name: 'Recepcao', active: true, latitude: -23, longitude: -45, radiusMeters: 100 },
      },
      user: { id: userId, name: 'Maria', role: 'RESIDENT', active: true },
      authorizations,
      credentialValid: true,
      credentialExpired: false,
      method: 'NFC',
      now,
    });
  }

  it('com massa historica carrega e bloqueia apenas a candidata utilizavel', async () => {
    const { userId, locationId } = await seedPlace();
    await seedBlock(userId, locationId, 2000, { startDays: 31, endDays: 30, canceled: true });
    await seedBlock(userId, locationId, 1000, { startDays: 21, endDays: 20 });
    await seedBlock(userId, locationId, 1000, { startDays: -1, endDays: -1, usedCount: 1 });
    const available = await insertAvailable(userId, locationId);

    const rows = await repository!.transaction(randomUUID(), (tx) =>
      tx.findAuthorizations(userId, locationId, now),
    );

    // Historico fora da leitura: no maximo a linha do motivo + a candidata.
    expect(rows.length).toBeLessThanOrEqual(2);
    expect(rows.filter((row) => !row.canceledAt && row.usedCount < row.maxUses).map((row) => row.id))
      .toEqual([available]);
    expect(decision(rows, userId, locationId)).toMatchObject({
      action: 'open',
      authorizationId: available,
    });
  });

  it.each([
    ['cancelada', { startDays: 31, endDays: 30, canceled: true }, 'AUTHORIZATION_CANCELED'],
    ['vencida', { startDays: 21, endDays: 20 }, 'AUTHORIZATION_EXPIRED'],
    ['agendada', { startDays: -2, endDays: -1 }, 'AUTHORIZATION_NOT_STARTED'],
    ['esgotada', { startDays: 1, endDays: -1, usedCount: 1 }, 'NO_USES_LEFT'],
  ] as const)('nega por autorizacao %s mantendo o motivo do dominio', async (_label, block, reason) => {
    const { userId, locationId } = await seedPlace();
    const blockIds = await seedBlock(userId, locationId, 5, block);

    const rows = await repository!.transaction(randomUUID(), (tx) =>
      tx.findAuthorizations(userId, locationId, now),
    );
    const legacy = decision((await pool!.query(LEGACY_SQL, [userId, locationId])).rows, userId, locationId);

    expect(rows.length).toBeLessThanOrEqual(blockIds.length);
    expect(decision(rows, userId, locationId)).toEqual(legacy);
    expect(legacy).toMatchObject({ action: 'deny', reason });
  });

  it('com historico misto a negativa mantem o motivo da primeira autorizacao', async () => {
    const { userId, locationId } = await seedPlace();
    const canceled = await seedBlock(userId, locationId, 1000, { startDays: 61, endDays: 60, canceled: true });
    const expired = await seedBlock(userId, locationId, 1000, { startDays: 41, endDays: 40 });
    const exhausted = await seedBlock(userId, locationId, 1000, { startDays: -1, endDays: -1, usedCount: 1 });
    const scheduled = await seedBlock(userId, locationId, 10, { startDays: -3, endDays: -2 });

    const rows = await repository!.transaction(randomUUID(), (tx) =>
      tx.findAuthorizations(userId, locationId, now),
    );
    const legacy = decision((await pool!.query(LEGACY_SQL, [userId, locationId])).rows, userId, locationId);

    expect(rows.filter((row) => [...expired, ...exhausted].includes(row.id))).toEqual([]);
    expect(rows.filter((row) => canceled.includes(row.id)).length).toBeLessThanOrEqual(1);
    expect(rows.length).toBeLessThanOrEqual(scheduled.length + 1);
    expect(decision(rows, userId, locationId)).toEqual(legacy);
    expect(legacy).toMatchObject({ action: 'deny', reason: 'AUTHORIZATION_CANCELED' });
  });

  it('duas tentativas concorrentes disputam o ultimo uso e so uma consome', async () => {
    const { userId, locationId } = await seedPlace();
    const authorizationId = await insertAvailable(userId, locationId, 1);

    const attempt = () =>
      repository!.transaction(randomUUID(), async (tx) => {
        const rows = await tx.findAuthorizations(userId, locationId, new Date());
        const candidate = rows.find(
          (row) => !row.canceledAt && row.startsAt <= new Date() && row.endsAt >= new Date() && row.usedCount < row.maxUses,
        );
        if (!candidate) return 'sem-candidata';
        return (await tx.consumeAuthorization(candidate.id, new Date())) ? 'consumiu' : 'perdeu';
      });

    const results = await Promise.all([attempt(), attempt()]);

    expect(results.sort()).toEqual(['consumiu', 'sem-candidata']);
    expect(
      (await pool!.query('SELECT "usedCount" FROM "Authorization" WHERE id=$1', [authorizationId])).rows[0].usedCount,
    ).toBe(1);
  });

  it('o plano da candidata usa o indice novo e nao varre a tabela inteira', async () => {
    const { userId, locationId } = await seedPlace();
    await seedBlock(userId, locationId, 2000, { startDays: 31, endDays: 30, canceled: true });
    await seedBlock(userId, locationId, 1000, { startDays: 21, endDays: 20 });
    await insertAvailable(userId, locationId);
    await pool!.query('ANALYZE "Authorization"');

    const explained = await pool!.query<{ 'QUERY PLAN': unknown }>(
      `EXPLAIN (FORMAT JSON) ${AUTHORIZATION_CANDIDATES_SQL}`,
      [userId, locationId, now.toISOString()],
    );
    const serialized = JSON.stringify(explained.rows[0]!['QUERY PLAN']);

    expect(serialized).toContain('Authorization_userId_locationId_endsAt_id_idx');
    expect(serialized).not.toContain('"Node Type":"Seq Scan"');
  });
});
