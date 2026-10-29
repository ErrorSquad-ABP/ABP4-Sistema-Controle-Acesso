import type { DedupPurgeResult } from '../../application/terminal/purge-processed-messages.use-case.js';
import type { Clock } from '../../domain/ports/clock.js';
import { DEDUP_PURGE_INTERVAL_MS } from '../../domain/terminal/dedup-retention.js';
import type { Logger } from '../../shared/logger.js';
import type { Scheduler } from './keep-alive.js';

interface Purge {
  execute(): Promise<DedupPurgeResult>;
}

/** Ultima execucao do expurgo, exposta no `/healthz` sem nova consulta ao banco. */
export type DedupPurgeReport =
  | ({ at: string; status: 'ok' } & DedupPurgeResult)
  | { at: string; status: 'error'; error: string };

function run(purge: Purge, clock: Clock, logger: Logger, onReport: (report: DedupPurgeReport) => void): void {
  purge.execute().then(
    (result) => {
      logger.info('expurgo da deduplicacao concluido', { ...result });
      onReport({ at: clock.now().toISOString(), status: 'ok', ...result });
    },
    (err: unknown) => {
      const error = err instanceof Error ? err.message : String(err);
      logger.error('falha no expurgo da deduplicacao', { error });
      onReport({ at: clock.now().toISOString(), status: 'error', error });
    },
  );
}

/**
 * Expurgo periodico do `ProcessedAccessMessage` (DT-15). Mesmo molde do
 * `scheduleCommandPurge`: roda no boot e a cada 24 h, porque o worker do Render
 * reinicia e nao pode depender de um processo de vida longa.
 */
export function scheduleDedupPurge(
  purge: Purge,
  scheduler: Scheduler,
  clock: Clock,
  logger: Logger,
  onReport: (report: DedupPurgeReport) => void,
  intervalMs = DEDUP_PURGE_INTERVAL_MS,
): () => void {
  run(purge, clock, logger, onReport);
  return scheduler.every(intervalMs, () => run(purge, clock, logger, onReport));
}
