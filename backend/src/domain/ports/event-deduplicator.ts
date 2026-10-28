export type Deduplicated<T> = { duplicate: true } | { duplicate: false; value: T };

/** Serializa o mesmo evento e registra somente execucoes bem-sucedidas. */
export interface EventDeduplicator {
  run<T>(id: string, work: () => Promise<T>): Promise<Deduplicated<T>>;
}
