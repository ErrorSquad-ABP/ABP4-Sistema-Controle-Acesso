import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { Logger } from '../../shared/logger.js';
import type { PublishCommandUseCase } from './publish-command.use-case.js';

/** Folga para nao republicar o que o publicador original ainda esta enviando. */
export const DISPATCH_GRACE_MS = 1_500;
/**
 * Reserva de um processo que morreu entre marcar e publicar. Acima do prazo do
 * comando (10 s) de proposito: so a reserva orfa volta, nunca a de um relay vivo.
 */
export const CLAIM_STALE_MS = 60_000;
const BATCH_SIZE = 50;

export interface DispatchPendingCommandsOutput {
  /** Intencoes reservadas neste ciclo. */
  claimed: number;
  published: number;
  skipped: number;
  /** Reservas devolvidas por falha de transporte; o proximo ciclo tenta de novo. */
  failed: number;
  /** `true` quando o broker falhou e o ciclo parou. */
  interrupted: boolean;
}

/**
 * Relay da outbox (DT-13): publica as intencoes gravadas na decisao que nao
 * chegaram ao broker (falha de transporte ou reinicio), com o mesmo `commandId`
 * e prazo. Nunca publica vencido nem para terminal/local fora de operacao.
 *
 * Cada intencao e reservada no store antes da publicacao: duas replicas do worker
 * nao publicam o mesmo comando. A entrega continua *at-least-once* — a reserva
 * pode ser devolvida depois de um publish que chegou ao broker e, quando o
 * processo morre entre marcar e publicar, a reserva orfa expira em
 * `CLAIM_STALE_MS`. O terminal deduplica por `commandId`.
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
    const claimed = await this.store.claimUndispatched(
      now,
      new Date(now.getTime() - DISPATCH_GRACE_MS),
      BATCH_SIZE,
      new Date(now.getTime() - CLAIM_STALE_MS),
    );
    const output: DispatchPendingCommandsOutput = {
      claimed: claimed.length,
      published: 0,
      skipped: 0,
      failed: 0,
      interrupted: false,
    };

    for (const command of claimed) {
      if (command.action === 'open' && !(await this.access.canDispatch(command.terminalId))) {
        // Fica pendente e vence sozinho: reativar dentro do prazo ainda entrega.
        await this.store.releaseClaim(command.commandId);
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
          // Vencido entre a reserva e o envio: nao volta para a fila.
          output.skipped += 1;
        }
      } catch (error) {
        await this.store.releaseClaim(command.commandId);
        this.logger.warn('relay de comandos sem broker; nova tentativa no proximo ciclo', {
          commandId: command.commandId,
          error: error instanceof Error ? error.message : String(error),
        });
        output.failed += 1;
        output.interrupted = true;
        break;
      }
    }
    return output;
  }
}
