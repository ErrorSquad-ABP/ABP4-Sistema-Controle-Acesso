import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { Logger } from '../../shared/logger.js';
import type { PublishCommandUseCase } from './publish-command.use-case.js';

/** Folga para nao republicar o que o publicador original ainda esta enviando. */
export const DISPATCH_GRACE_MS = 1_500;
const BATCH_SIZE = 50;

export interface DispatchPendingCommandsOutput {
  published: number;
  skipped: number;
  /** `true` quando o broker falhou e o ciclo parou; o proximo tenta de novo. */
  interrupted: boolean;
}

/**
 * Relay da outbox (DT-13): publica as intencoes gravadas na decisao que nao
 * chegaram ao broker (falha de transporte ou reinicio), com o mesmo `commandId`
 * e prazo. Nunca publica vencido nem para terminal/local fora de operacao.
 */
export class DispatchPendingCommandsUseCase {
  constructor(
    private readonly store: CommandStore,
    private readonly access: Pick<AccessRepository, 'canDispatch'>,
    private readonly publish: PublishCommandUseCase,
    private readonly clock: Clock,
    private readonly logger: Logger,
  ) {}

  async execute(): Promise<DispatchPendingCommandsOutput> {
    const now = this.clock.now();
    const pending = await this.store.listUndispatched(
      now,
      new Date(now.getTime() - DISPATCH_GRACE_MS),
      BATCH_SIZE,
    );
    const output: DispatchPendingCommandsOutput = { published: 0, skipped: 0, interrupted: false };

    for (const command of pending) {
      if (command.action === 'open' && !(await this.access.canDispatch(command.terminalId))) {
        // Fica pendente e vence sozinho: reativar dentro do prazo ainda entrega.
        this.logger.warn('comando pendente retido: terminal ou local inativo', {
          terminalId: command.terminalId,
          commandId: command.commandId,
        });
        output.skipped += 1;
        continue;
      }
      try {
        if (await this.publish.dispatch(command)) {
          output.published += 1;
          this.logger.info('comando pendente publicado', {
            terminalId: command.terminalId,
            commandId: command.commandId,
            action: command.action,
          });
        } else {
          output.skipped += 1;
        }
      } catch (error) {
        this.logger.warn('relay de comandos sem broker; nova tentativa no proximo ciclo', {
          commandId: command.commandId,
          error: error instanceof Error ? error.message : String(error),
        });
        output.interrupted = true;
        break;
      }
    }
    return output;
  }
}
