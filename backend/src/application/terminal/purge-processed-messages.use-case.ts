import type { ProcessedMessageRetention, ProcessedMessageStats } from '../../domain/ports/event-deduplicator.js';
import {
  DEDUP_PURGE_BATCH_SIZE,
  DEDUP_PURGE_MAX_BATCHES,
  DEDUP_RETENTION_MS,
} from '../../domain/terminal/dedup-retention.js';

export interface DedupPurgeResult extends ProcessedMessageStats {
  removed: number;
}

/**
 * Apaga marcas de deduplicacao fora da retencao, em lotes limitados, e mede a
 * tabela depois. O resultado vai para o log e para o `/healthz` do worker (DT-15).
 */
export class PurgeProcessedMessagesUseCase {
  constructor(private readonly retention: ProcessedMessageRetention) {}

  async execute(): Promise<DedupPurgeResult> {
    let removed = 0;
    for (let batch = 0; batch < DEDUP_PURGE_MAX_BATCHES; batch += 1) {
      const count = await this.retention.purgeProcessed(DEDUP_RETENTION_MS, DEDUP_PURGE_BATCH_SIZE);
      removed += count;
      if (count < DEDUP_PURGE_BATCH_SIZE) break;
    }
    return { removed, ...(await this.retention.stats()) };
  }
}
