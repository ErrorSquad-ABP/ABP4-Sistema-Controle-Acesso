export type Deduplicated<T> = { duplicate: true } | { duplicate: false; value: T };

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
