import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import {
  COMMAND_PURGE_BATCH_SIZE,
  COMMAND_PURGE_MAX_BATCHES,
  COMMAND_RETENTION_MS,
} from '../../domain/terminal/command-retention.js';

/**
 * Apaga comandos expirados ha mais que a retencao, em lotes limitados.
 * Devolve o total removido para o log de cada execucao (DT-18).
 */
export class PurgeExpiredCommandsUseCase {
  constructor(
    private readonly store: CommandStore,
    private readonly clock: Clock,
  ) {}

  async execute(): Promise<number> {
    const before = new Date(this.clock.now().getTime() - COMMAND_RETENTION_MS);
    let removed = 0;
    for (let batch = 0; batch < COMMAND_PURGE_MAX_BATCHES; batch += 1) {
      const count = await this.store.purgeExpired(before, COMMAND_PURGE_BATCH_SIZE);
      removed += count;
      if (count < COMMAND_PURGE_BATCH_SIZE) break;
    }
    return removed;
  }
}
