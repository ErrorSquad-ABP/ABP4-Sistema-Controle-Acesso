export type Deduplicated<T> = { duplicate: true } | { duplicate: false; value: T };

/**
 * Outra execucao mantem a reserva do mesmo evento e o prazo de espera estourou.
 * O evento nao foi processado nem marcado; a retransmissao fica para o proximo ciclo.
 */
export class DeduplicationBusyError extends Error {
  constructor(readonly postgresCode?: string) {
    super('reserva da deduplicacao excedeu o prazo');
    this.name = 'DeduplicationBusyError';
  }
}

/** Serializa o mesmo evento e registra somente execucoes bem-sucedidas. */
export interface EventDeduplicator {
  run<T>(id: string, work: () => Promise<T>): Promise<Deduplicated<T>>;
}

export interface ProcessedMessageStats {
  rows: number;
  bytes: number;
}

/** Retencao da deduplicacao persistente (DT-15); o adapter em memoria ja e limitado. */
export interface ProcessedMessageRetention {
  /** Apaga ate `limit` marcas com mais de `olderThanMs`, no relogio do banco. */
  purgeProcessed(olderThanMs: number, limit: number): Promise<number>;
  stats(): Promise<ProcessedMessageStats>;
}
