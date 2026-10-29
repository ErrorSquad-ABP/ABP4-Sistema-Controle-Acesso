import { COMMAND_PURGE_INTERVAL_MS } from '../../domain/terminal/command-retention.js';
import type { Logger } from '../../shared/logger.js';
import type { Scheduler } from './keep-alive.js';

interface Purge {
  execute(): Promise<number>;
}

function run(purge: Purge, logger: Logger): void {
  purge.execute().then(
    (removed) => logger.info('expurgo de comandos concluido', { removed }),
    (error: unknown) =>
      logger.error('falha no expurgo de comandos', {
        error: error instanceof Error ? error.message : String(error),
      }),
  );
}

/**
 * Expurgo periodico do `TerminalCommand` (DT-18). Roda uma vez no boot e depois
 * a cada 24 h: o worker do Render reinicia, entao esperar o primeiro intervalo
 * deixaria o expurgo dependente de um processo de vida longa.
 */
export function scheduleCommandPurge(
  purge: Purge,
  scheduler: Scheduler,
  logger: Logger,
  intervalMs = COMMAND_PURGE_INTERVAL_MS,
): () => void {
  run(purge, logger);
  return scheduler.every(intervalMs, () => run(purge, logger));
}
