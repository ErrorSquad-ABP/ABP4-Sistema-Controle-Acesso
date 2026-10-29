import type { AccessRepository } from '../../domain/ports/access-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { CommandStore } from '../../domain/ports/command-store.js';
import type { Logger } from '../../shared/logger.js';
import type { PublishCommandUseCase } from './publish-command.use-case.js';

/** Folga para nao republicar o que o publicador original ainda esta enviando. */
export const DISPATCH_GRACE_MS = 1_500;
/**
 * Idade maxima de uma reserva antes de outra replica poder retoma-la. O claim reserva
 * um comando por vez, entao a reserva dura so o publish daquele comando (teto de 3 s
 * do PUBACK): um relay vivo nao perde o que ainda esta enviando, e so a reserva de um
 * processo que morreu entre marcar e publicar chega aqui. Precisa caber no prazo do
 * comando (10 s): a consulta exige `expiresAt > now`, entao uma janela acima do TTL
 * nunca reclama nada.
 */
export const CLAIM_STALE_MS = 5_000;
const BATCH_SIZE = 50;

export interface DispatchPendingCommandsOutput {
  /** Intencoes reservadas neste ciclo. */
  claimed: number;
  published: number;
  skipped: number;
  /**
   * Comandos cuja publicacao saiu anormal (transporte, checagem, excecao). A reserva
   * e devolvida na hora; se a devolucao tambem falhar, expira em `CLAIM_STALE_MS`.
   */
  failed: number;
  /** `true` quando o ciclo parou e devolveu a reserva do comando corrente. */
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
 * Cada intencao e reservada no store antes da publicacao, uma por vez: duas replicas
 * do worker nao publicam o mesmo comando, e a reserva cobre so o envio daquele
 * comando (nao um lote que ficaria velho enquanto os primeiros ainda saem). A entrega
 * continua *at-least-once* — a reserva pode ser devolvida depois de um publish que
 * chegou ao broker e, quando o processo morre entre marcar e publicar, a reserva orfa
 * expira em `CLAIM_STALE_MS`. O terminal deduplica por `commandId`.
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
    const output: DispatchPendingCommandsOutput = {
      claimed: 0,
      published: 0,
      skipped: 0,
      failed: 0,
      interrupted: false,
      backlog: false,
    };

    // Reservas de comandos retidos (terminal/local inativo). Nao serao publicados neste
    // ciclo, entao a devolucao espera o fim: liberar na hora faria o proximo claim
    // devolver o mesmo comando para sempre e travaria a fila atras dele.
    const retained: string[] = [];

    // Uma reserva por comando: a janela de `CLAIM_STALE_MS` cobre so o publish em voo,
    // entao a fila pode ser longa sem que o fim dela pareca abandonado.
    while (output.claimed < BATCH_SIZE) {
      const now = this.clock.now();
      const [command] = await this.store.claimUndispatched(
        now,
        new Date(now.getTime() - DISPATCH_GRACE_MS),
        1,
        new Date(now.getTime() - CLAIM_STALE_MS),
      );
      if (!command) break;
      output.claimed += 1;

      try {
        if (command.action === 'open' && !(await this.access.canDispatch(command.terminalId))) {
          // Fica pendente e vence sozinho: reativar dentro do prazo ainda entrega.
          retained.push(command.commandId);
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
        // So o comando corrente estava reservado: devolve a reserva dele e para o ciclo.
        await this.release(command.commandId);
        output.failed += 1;
        output.interrupted = true;
        this.logger.warn('relay de comandos interrompido; reserva devolvida', {
          commandId: command.commandId,
          error: error instanceof Error ? error.message : String(error),
        });
        break;
      }
    }

    for (const commandId of retained) await this.release(commandId);
    output.backlog = output.claimed >= BATCH_SIZE;
    return output;
  }

  /** Devolve a reserva sem derrubar o ciclo: se falhar, ela expira em `CLAIM_STALE_MS`. */
  private async release(commandId: string): Promise<void> {
    try {
      await this.store.releaseClaim(commandId);
    } catch (error) {
      this.logger.error('falha ao devolver reserva do relay', {
        commandId,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  }
}
