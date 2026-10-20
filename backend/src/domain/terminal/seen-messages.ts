/**
 * Memoria curta de ids ja processados. QoS 1 pode entregar a mesma mensagem
 * duas vezes; o consumidor descarta a repeticao (janela FIFO limitada).
 */
export class SeenMessages {
  private readonly ids = new Set<string>();

  constructor(private readonly capacity = 1000) {}

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
