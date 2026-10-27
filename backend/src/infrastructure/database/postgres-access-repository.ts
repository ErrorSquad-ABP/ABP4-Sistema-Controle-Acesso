import type pg from 'pg';
import type { AccessAuthorization, AccessUser, TerminalContext } from '../../domain/access/access-policy.js';
import type {
  AccessCredential,
  AccessRecord,
  AccessRepository,
  AccessTransaction,
} from '../../domain/ports/access-repository.js';
import type { CommandMessage } from '../../domain/terminal/messages.js';

type Connection = pg.Pool | pg.PoolClient;

interface EventRow {
  id: string; terminalId: string | null; occurredAt: Date; method: AccessRecord['method'];
  decision: AccessRecord['decision']; reason: AccessRecord['reason']; authorizationId: string | null;
  credentialId: string | null; latitude: string | null; longitude: string | null; distanceMeters: string | null;
  user: AccessUser | null; location: { id: string; name: string } | null;
}

// Prisma persiste TIMESTAMP sem fuso em UTC. Converta para timestamptz na borda SQL,
// evitando que o pg interprete esses campos no fuso local do processo Node.
const eventSelect = `SELECT e.id,e."terminalId",e.method,e.decision,e.reason,e."authorizationId",e."credentialId",
  e.latitude,e.longitude,e."distanceMeters",e."occurredAt" AT TIME ZONE 'UTC' AS "occurredAt", CASE WHEN u.id IS NULL THEN NULL ELSE
  json_build_object('id',u.id,'name',u.name,'role',u.role,'active',u.active) END AS "user",
  CASE WHEN l.id IS NULL THEN NULL ELSE json_build_object('id',l.id,'name',l.name) END AS location
  FROM "AccessEvent" e LEFT JOIN "User" u ON u.id=e."userId" LEFT JOIN "AccessLocation" l ON l.id=e."locationId"`;

function mapEvent(row: EventRow): AccessRecord {
  return {
    ...row,
    occurredAt: row.occurredAt.toISOString(),
    latitude: row.latitude === null ? null : Number(row.latitude),
    longitude: row.longitude === null ? null : Number(row.longitude),
    distanceMeters: row.distanceMeters === null ? null : Number(row.distanceMeters),
  };
}

class PostgresAccessTransaction implements AccessTransaction {
  constructor(private readonly connection: Connection) {}

  async findEvent(id: string): Promise<AccessRecord | null> {
    const result = await this.connection.query<EventRow>(`${eventSelect} WHERE e.id=$1`, [id]);
    return result.rows[0] ? mapEvent(result.rows[0]) : null;
  }

  async findUser(id: string): Promise<AccessUser | null> {
    const result = await this.connection.query<AccessUser>('SELECT id,name,role,active FROM "User" WHERE id=$1', [id]);
    return result.rows[0] ?? null;
  }

  async findTerminal(id: string): Promise<TerminalContext | null> {
    const result = await this.connection.query<{ id: string; active: boolean; location: TerminalContext['location'] }>(
      `SELECT t.id,t.active,
        json_build_object('id',l.id,'name',l.name,'active',l."isActive",'latitude',l.latitude::float8,
        'longitude',l.longitude::float8,'radiusMeters',l."radiusMeters") AS location
        FROM "Terminal" t JOIN "AccessLocation" l ON l.id=t."locationId" WHERE t.id=$1`,
      [id],
    );
    return result.rows[0] ?? null;
  }

  async findCredential(hash: string): Promise<AccessCredential | null> {
    const result = await this.connection.query<AccessCredential>(
      `SELECT c.id,
        c."validFrom" AT TIME ZONE 'UTC' AS "validFrom", c."validUntil" AT TIME ZONE 'UTC' AS "validUntil",
        c."revokedAt" AT TIME ZONE 'UTC' AS "revokedAt",
        json_build_object('id',u.id,'name',u.name,'role',u.role,'active',u.active) AS "user"
        FROM "Credential" c JOIN "User" u ON u.id=c."userId" WHERE c."valueHash"=$1 AND c.type='NFC'`,
      [hash],
    );
    return result.rows[0] ?? null;
  }

  async findAuthorizations(userId: string, locationId: string): Promise<AccessAuthorization[]> {
    // Ordem estavel e lock: duas instancias nao podem gastar o mesmo ultimo uso.
    const result = await this.connection.query<AccessAuthorization>(
      `SELECT id,"userId","locationId","maxUses","usedCount",
        "startsAt" AT TIME ZONE 'UTC' AS "startsAt", "endsAt" AT TIME ZONE 'UTC' AS "endsAt",
        "canceledAt" AT TIME ZONE 'UTC' AS "canceledAt" FROM "Authorization"
        WHERE "userId"=$1 AND "locationId"=$2 ORDER BY "endsAt",id FOR UPDATE`,
      [userId, locationId],
    );
    return result.rows;
  }

  async consumeAuthorization(id: string, now: Date): Promise<boolean> {
    const result = await this.connection.query(
      `UPDATE "Authorization" SET "usedCount"="usedCount"+1,"updatedAt"=$2
        WHERE id=$1 AND "canceledAt" IS NULL AND "startsAt" <= $2 AND "endsAt" >= $2 AND "usedCount" < "maxUses"`,
      [id, now.toISOString()],
    );
    return result.rowCount === 1;
  }

  async record(event: AccessRecord): Promise<AccessRecord> {
    await this.connection.query(
      `INSERT INTO "AccessEvent"
        (id,"terminalId","userId","authorizationId","credentialId","locationId",method,decision,reason,
        latitude,longitude,"distanceMeters","occurredAt") VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11,$12,$13)`,
      [
        event.id, event.terminalId, event.user?.id ?? null, event.authorizationId, event.credentialId,
        event.location?.id ?? null, event.method, event.decision, event.reason, event.latitude,
        event.longitude, event.distanceMeters, event.occurredAt,
      ],
    );
    return event;
  }

  async saveCommand(command: CommandMessage, requestId: string): Promise<CommandMessage> {
    await this.connection.query(
      `INSERT INTO "TerminalCommand" ("commandId","requestId","terminalId",payload,"expiresAt")
        VALUES ($1,$2,$3,$4,$5) ON CONFLICT ("requestId") DO NOTHING`,
      [command.commandId, requestId, command.terminalId, JSON.stringify(command), command.expiresAt],
    );
    const saved = await this.connection.query<{ payload: CommandMessage }>(
      'SELECT payload FROM "TerminalCommand" WHERE "requestId"=$1',
      [requestId],
    );
    if (!saved.rows[0]) throw new Error('Comando nao persistido');
    return saved.rows[0].payload;
  }
}

export class PostgresAccessRepository implements AccessRepository {
  constructor(private readonly pool: pg.Pool) {}

  async ready(): Promise<void> {
    await this.pool.query('SELECT 1 FROM "Terminal", "TerminalCommand", "AccessEvent" LIMIT 0');
  }

  async transaction<T>(requestId: string, work: (tx: AccessTransaction) => Promise<T>): Promise<T> {
    const connection = await this.pool.connect();
    try {
      await connection.query('BEGIN');
      // Serializa retransmissoes entre workers sem depender de memoria local.
      await connection.query('SELECT pg_advisory_xact_lock(hashtextextended($1,0))', [requestId]);
      const result = await work(new PostgresAccessTransaction(connection));
      await connection.query('COMMIT');
      return result;
    } catch (error) {
      await connection.query('ROLLBACK');
      throw error;
    } finally {
      connection.release();
    }
  }
}
