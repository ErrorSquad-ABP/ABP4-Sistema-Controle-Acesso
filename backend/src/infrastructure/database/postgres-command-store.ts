import type pg from 'pg';
import type { CommandStore, AckResult } from '../../domain/ports/command-store.js';
import type { AckMessage, CommandMessage } from '../../domain/terminal/messages.js';

export class PostgresCommandStore implements CommandStore {
  constructor(private readonly pool: pg.Pool) {}
  async findByRequestId(requestId: string): Promise<CommandMessage | undefined> {
    const result = await this.pool.query<{ payload: CommandMessage }>('SELECT payload FROM "TerminalCommand" WHERE "requestId"=$1', [requestId]);
    return result.rows[0]?.payload;
  }
  async save(command: CommandMessage, requestId: string): Promise<CommandMessage> {
    await this.pool.query(`INSERT INTO "TerminalCommand" ("commandId","requestId","terminalId",payload,"expiresAt")
      VALUES ($1,$2,$3,$4,$5) ON CONFLICT ("requestId") DO NOTHING`,
    [command.commandId,requestId,command.terminalId,JSON.stringify(command),command.expiresAt]);
    const saved = await this.findByRequestId(requestId);
    if (!saved) throw new Error('Comando nao persistido');
    return saved;
  }
  async markPublished(commandId: string, at: Date): Promise<void> {
    await this.pool.query('UPDATE "TerminalCommand" SET "publishedAt"=$2 WHERE "commandId"=$1 AND "publishedAt" IS NULL',
      [commandId, at.toISOString()]);
  }
  async listUndispatched(now: Date, decidedBefore: Date, limit: number): Promise<CommandMessage[]> {
    // ISO em texto: as colunas sao TIMESTAMP sem fuso gravadas em UTC (ver save).
    const result = await this.pool.query<{ payload: CommandMessage }>(`SELECT payload FROM "TerminalCommand"
      WHERE "publishedAt" IS NULL AND "ackStatus" IS NULL AND "expiresAt" > $1
      AND (payload->>'timestamp')::timestamptz <= $2::timestamptz ORDER BY "expiresAt" LIMIT $3`,
    [now.toISOString(), decidedBefore.toISOString(), limit]);
    return result.rows.map((row) => row.payload);
  }
  async acknowledge(ack: AckMessage): Promise<AckResult> {
    const result = await this.pool.query<{ payload: CommandMessage }>(`UPDATE "TerminalCommand"
      SET "ackStatus"=$3,"ackMessageId"=$4,"ackReason"=$5,"acknowledgedAt"=now()
      WHERE "commandId"=$1 AND "terminalId"=$2 AND "ackStatus" IS NULL RETURNING payload`,
    [ack.commandId,ack.terminalId,ack.status,ack.messageId,ack.reason ?? null]);
    if (result.rows[0]) return { status: 'correlated', command: result.rows[0].payload };
    const previous = await this.pool.query('SELECT 1 FROM "TerminalCommand" WHERE "commandId"=$1 AND "terminalId"=$2 AND "ackStatus" IS NOT NULL', [ack.commandId,ack.terminalId]);
    return { status: previous.rowCount ? 'duplicate' : 'unknown' };
  }

  /** Lote unico: o indice de `expiresAt` mantem o DELETE barato (DT-18). */
  async purgeExpired(before: Date, limit: number): Promise<number> {
    const result = await this.pool.query(
      `DELETE FROM "TerminalCommand" WHERE "commandId" IN (
        SELECT "commandId" FROM "TerminalCommand" WHERE "expiresAt" < $1 ORDER BY "expiresAt" LIMIT $2)`,
      [before.toISOString(), limit],
    );
    return result.rowCount ?? 0;
  }
}
