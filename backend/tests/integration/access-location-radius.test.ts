import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';

const pool = process.env.DATABASE_URL ? new pg.Pool({ connectionString: process.env.DATABASE_URL }) : null;

describe.skipIf(!pool)('DT-23: raio do local no banco', () => {
  afterAll(async () => { await pool?.end(); });

  it.each([0, -1, 101, 200])('recusa cadastro com raio %i sem persistir o local', async (radius) => {
    const id = randomUUID();
    try {
      await expect(pool!.query(
        `INSERT INTO "AccessLocation" (id,name,latitude,longitude,"radiusMeters","updatedAt")
         VALUES ($1,'DT-23',-23,-45,$2,now())`, [id, radius],
      )).rejects.toMatchObject({ code: '23514', constraint: 'AccessLocation_radiusMeters_check' });
      expect((await pool!.query('SELECT 1 FROM "AccessLocation" WHERE id=$1', [id])).rowCount).toBe(0);
    } finally {
      await pool!.query('DELETE FROM "AccessLocation" WHERE id=$1', [id]);
    }
  });

  it.each([1, 40, 100])('preserva raio %i e recusa ampliacao acima de 100 m', async (radius) => {
    const id = randomUUID();
    try {
      await pool!.query(
        `INSERT INTO "AccessLocation" (id,name,latitude,longitude,"radiusMeters","updatedAt")
         VALUES ($1,'DT-23',-23,-45,$2,now())`, [id, radius],
      );
      await expect(pool!.query('UPDATE "AccessLocation" SET "radiusMeters"=200 WHERE id=$1', [id]))
        .rejects.toMatchObject({ code: '23514', constraint: 'AccessLocation_radiusMeters_check' });
      expect((await pool!.query('SELECT "radiusMeters" FROM "AccessLocation" WHERE id=$1', [id])).rows[0].radiusMeters)
        .toBe(radius);
    } finally {
      await pool!.query('DELETE FROM "AccessLocation" WHERE id=$1', [id]);
    }
  });
});
