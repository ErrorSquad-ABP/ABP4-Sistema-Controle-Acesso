import { randomUUID } from 'node:crypto';
import pg from 'pg';
import { afterAll, describe, expect, it } from 'vitest';
import { PurgeProcessedMessagesUseCase } from '../../src/application/terminal/purge-processed-messages.use-case.js';
import { DEDUP_RETENTION_MS } from '../../src/domain/terminal/dedup-retention.js';
import { PostgresEventDeduplicator } from '../../src/infrastructure/database/postgres-event-deduplicator.js';

const connectionString = process.env.DATABASE_URL;
// Sem `timezone` fixo: igual a pool de eventos do worker, que tambem usa o fuso do servidor.
const pool = connectionString ? new pg.Pool({ connectionString, max: 2 }) : null;

const HOUR_MS = 60 * 60_000;

// Sem banco local o teste e pulado; no CI o Postgres do job sempre existe.
describe.skipIf(!pool)('PostgresEventDeduplicator (DT-15)', () => {
  const dedup = pool ? new PostgresEventDeduplicator(pool) : null;

  /** Marca gravada `ageMs` atras no relogio do banco, como o `DEFAULT` faria naquela hora. */
  async function insertProcessed(ageMs: number, messageId = randomUUID()) {
    await pool!.query(
      `INSERT INTO "ProcessedAccessMessage" ("messageId","processedAt")
       VALUES ($1, LOCALTIMESTAMP - make_interval(secs => $2))`,
      [messageId, ageMs / 1000],
    );
    return messageId;
  }

  async function remaining(messageIds: string[]) {
    const result = await pool!.query(
      'SELECT count(*)::int AS total FROM "ProcessedAccessMessage" WHERE "messageId" = ANY($1::uuid[])',
      [messageIds],
    );
    return result.rows[0].total as number;
  }

  afterAll(async () => {
    await pool?.end();
  });

  it('apaga so o que passou da retencao, em lotes', async () => {
    const antigos = [
      await insertProcessed(30 * 24 * HOUR_MS),
      await insertProcessed(3 * 24 * HOUR_MS),
      await insertProcessed(DEDUP_RETENTION_MS + HOUR_MS),
    ];
    const preservados = [
      await insertProcessed(DEDUP_RETENTION_MS - HOUR_MS), // ainda dentro das 24 h
      await insertProcessed(35_000), // retransmissao ainda aceita pelo frescor
      await insertProcessed(0),
    ];

    expect(await dedup!.purgeProcessed(DEDUP_RETENTION_MS, 2)).toBe(2);
    expect(await remaining(antigos)).toBe(1);
    expect(await remaining(preservados)).toBe(3);

    expect(await dedup!.purgeProcessed(DEDUP_RETENTION_MS, 2)).toBe(1);
    expect(await remaining(antigos)).toBe(0);
    expect(await remaining(preservados)).toBe(3);
  });

  it('mensagem ainda elegivel continua deduplicada depois do expurgo', async () => {
    const recente = randomUUID();
    const first = await dedup!.run(recente, async () => 'decidido');
    expect(first).toEqual({ duplicate: false, value: 'decidido' });
    await insertProcessed(2 * DEDUP_RETENTION_MS);

    const result = await new PurgeProcessedMessagesUseCase(dedup!).execute();
    expect(result.removed).toBeGreaterThanOrEqual(1);

    let executed = false;
    const replay = await dedup!.run(recente.toUpperCase(), async () => {
      executed = true;
    });
    expect(replay).toEqual({ duplicate: true });
    expect(executed).toBe(false);
  });

  it('mede contagem e tamanho da tabela', async () => {
    await insertProcessed(0);
    const { rows: before } = await dedup!.stats();
    await insertProcessed(0);

    const stats = await dedup!.stats();
    expect(stats.rows).toBe(before + 1);
    expect(stats.bytes).toBeGreaterThan(0);
  });
});

// Conexoes independentes: cada pool simula uma replica do worker (DT-16).
const contention = connectionString
  ? [new pg.Pool({ connectionString, max: 2 }), new pg.Pool({ connectionString, max: 2 })]
  : null;
const SHORT = { lockMs: 300, statementMs: 400, reservationMs: 800 };

describe.skipIf(!contention)('PostgresEventDeduplicator: prazos da reserva (DT-16)', () => {
  const [poolA, poolB] = contention ?? [];
  const a = poolA ? new PostgresEventDeduplicator(poolA, SHORT) : null;
  const b = poolB ? new PostgresEventDeduplicator(poolB, SHORT) : null;

  async function marked(messageId: string) {
    return (await poolB!.query('SELECT 1 FROM "ProcessedAccessMessage" WHERE "messageId" = $1', [messageId])).rowCount;
  }

  afterAll(async () => {
    await poolA?.end();
    await poolB?.end();
  });

  it('duplicata bloqueada desiste no prazo, sem marca, e a posterior prossegue', async () => {
    const id = randomUUID();
    let release!: () => void;
    let reserved!: () => void;
    const holding = new Promise<void>((resolve) => { reserved = resolve; });
    const first = a!.run(id, async () => {
      reserved();
      await new Promise<void>((resolve) => { release = resolve; });
      return 'primeira';
    });
    await holding;

    const started = Date.now();
    let executed = false;
    await expect(b!.run(id, async () => { executed = true; })).rejects.toThrow('reserva da deduplicacao excedeu o prazo');
    const elapsed = Date.now() - started;
    expect(elapsed).toBeGreaterThanOrEqual(SHORT.lockMs - 50);
    expect(elapsed).toBeLessThan(SHORT.lockMs + 1_000);
    expect(executed).toBe(false);
    expect(await marked(id)).toBe(0);

    // A conexao de B voltou limpa: outro id na mesma pool reserva na hora.
    expect(await b!.run(randomUUID(), async () => 'outro')).toEqual({ duplicate: false, value: 'outro' });

    release();
    expect(await first).toEqual({ duplicate: false, value: 'primeira' });
    expect(await b!.run(id, async () => 'replay')).toEqual({ duplicate: true });
  });

  it('callback travado alem do teto perde a reserva sem marca e outra replica processa', async () => {
    const id = randomUUID();
    let callbackDone = false;
    const stuck = a!.run(id, async () => {
      await new Promise((resolve) => setTimeout(resolve, SHORT.reservationMs * 4));
      callbackDone = true;
      return 'tarde';
    });
    const settled = stuck.catch((err: unknown) => err as Error);

    // Passado o teto, o servidor encerra a sessao de A e solta o lock com o callback ainda rodando.
    await new Promise((resolve) => setTimeout(resolve, SHORT.reservationMs * 2));
    expect(callbackDone).toBe(false);
    expect(await marked(id)).toBe(0);
    const started = Date.now();
    expect(await b!.run(id, async () => 'retentativa')).toEqual({ duplicate: false, value: 'retentativa' });
    expect(Date.now() - started).toBeLessThan(SHORT.lockMs);

    // A nao confirma nada ao terminar: a sessao ja tinha caido.
    expect(await settled).toBeInstanceOf(Error);
    expect(callbackDone).toBe(true);
    expect(await marked(id)).toBe(1);
    // A pool de A segue utilizavel: a conexao encerrada foi descartada.
    expect(await a!.run(randomUUID(), async () => 'nova')).toEqual({ duplicate: false, value: 'nova' });
  });
});
