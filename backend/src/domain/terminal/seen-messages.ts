import type { Deduplicated, EventDeduplicator } from '../ports/event-deduplicator.js';

/**
 * Memoria curta de ids ja processados. QoS 1 pode entregar a mesma mensagem
 * duas vezes; o consumidor descarta a repeticao (janela FIFO limitada).
 */
export class SeenMessages implements EventDeduplicator {
  private readonly ids = new Set<string>();
  private readonly inFlight = new Set<string>();

  constructor(private readonly capacity = 1000) {}

  /** Adapter volatil para simulacao/testes; producao usa persistencia PostgreSQL. */
  async run<T>(id: string, work: () => Promise<T>): Promise<Deduplicated<T>> {
    if (this.ids.has(id) || this.inFlight.has(id)) return { duplicate: true };
    this.inFlight.add(id);
    try {
      const value = await work();
      this.markIfNew(id);
      return { duplicate: false, value };
    } finally {
      this.inFlight.delete(id);
    }
  }

  /** Libera o id para que uma republicacao da mesma mensagem seja processada de novo. */
  forget(id: string): void {
    this.ids.delete(id);
  }

  /** `true` na primeira vez que o id aparece; `false` se for repeticao. */
  markIfNew(id: string): boolean {
    if (this.ids.has(id)) return false;
    this.ids.add(id);
    if (this.ids.size > this.capacity) {
      const oldest = this.ids.values().next().value;
      if (oldest !== undefined) this.ids.delete(oldest);
    }
    return true;
  }
}
