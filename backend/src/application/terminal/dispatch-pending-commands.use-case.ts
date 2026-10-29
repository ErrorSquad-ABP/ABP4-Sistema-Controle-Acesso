import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { Logger } from '../../shared/logger.js';
import type { PublishCommandUseCase } from './publish-command.use-case.js';

/** Folga para nao republicar o que o publicador original ainda esta enviando. */
export const DISPATCH_GRACE_MS = 1_500;
/**
 * Idade maxima de uma reserva antes de outra replica poder retoma-la. Precisa caber
 * no prazo do comando (10 s): a consulta exige `expiresAt > now`, entao uma janela
 * acima do TTL nunca reclama nada. Fica acima do teto de PUBACK (3 s), para um relay
 * vivo nunca perder a reserva; um processo morto a libera com o comando ainda valido.
 */
export const CLAIM_STALE_MS = 5_000;
const BATCH_SIZE = 50;

export interface DispatchPendingCommandsOutput {
  /** Intencoes reservadas neste ciclo. */
  claimed: number;
  published: number;
  skipped: number;
  /** Reservas devolvidas por saida anormal (transporte, checagem, excecao). */
  failed: number;
  /** `true` quando o ciclo parou e devolveu o que ainda nao tinha processado. */
  interrupted: boolean;
  /**
   * Lote cheio: a fila pode ter mais pendentes que os `BATCH_SIZE` deste ciclo.
   * Sinal de backlog sem custo; um `count(*)` por ciclo sairia caro para o Neon.
   */
  backlog: boolean;
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
      backlog: claimed.length >= BATCH_SIZE,
    };

    for (let index = 0; index < claimed.length; index += 1) {
      const command = claimed[index]!;
      try {
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
        // Qualquer saida anormal devolve o lote inteiro: as reservas restantes nunca
        // foram tentadas e ficariam presas (o comando vale 10 s), sem volta no TTL.
        output.failed += await this.releaseFrom(claimed, index);
        output.interrupted = true;
        this.logger.warn('relay de comandos interrompido; reservas devolvidas', {
          commandId: command.commandId,
          released: output.failed,
          error: error instanceof Error ? error.message : String(error),
        });
        break;
      }
    }
    return output;
  }

  /** Devolve da posicao `from` ao fim; uma falha ao devolver nao impede as demais. */
  private async releaseFrom(claimed: readonly { commandId: string }[], from: number): Promise<number> {
    let released = 0;
    for (const command of claimed.slice(from)) {
      try {
        await this.store.releaseClaim(command.commandId);
        released += 1;
      } catch (error) {
        this.logger.error('falha ao devolver reserva do relay', {
          commandId: command.commandId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }
    return released;
  }
}
