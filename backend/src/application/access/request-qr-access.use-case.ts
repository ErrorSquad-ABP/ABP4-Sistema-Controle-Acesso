import { DomainError, ServiceUnavailableError } from '../../domain/errors/domain-error.js';
import type { AccessRecord, AccessRepository } from '../../domain/ports/access-repository.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { Logger } from '../../shared/logger.js';
import type { DecideAccessUseCase } from './decide-access.use-case.js';
import type { PublishCommandUseCase } from '../terminal/publish-command.use-case.js';

export interface QrAccessInput {
  /** Repetir o mesmo valor devolve o mesmo evento e o mesmo comando (idempotencia). */
  requestId?: string | undefined;
  userId: string;
  terminalId: string;
  qrToken: string;
  position: { latitude: number; longitude: number };
}

export interface QrAccessOutput {
  decision: AccessRecord['decision'];
  reason: AccessRecord['reason'];
  message: string;
  event: AccessRecord;
  /** `false` com GRANTED: intencao pendente, entregue pelo relay do worker dentro do prazo (DT-13). */
  commandPublished: boolean;
}

export class RequestQrAccessUseCase {
  constructor(
    private readonly decide: DecideAccessUseCase,
    private readonly publish: PublishCommandUseCase,
    private readonly ids: IdGenerator,
    private readonly access: AccessRepository,
    private readonly logger: Logger,
  ) {}

  async execute(input: QrAccessInput): Promise<QrAccessOutput> {
    const event = await this.decide.execute({
      id: input.requestId ?? this.ids.uuid(),
      terminalId: input.terminalId,
      method: 'QR',
      userId: input.userId,
      qrToken: input.qrToken,
      position: input.position,
    });

    let commandPublished = false;
    if (event.decision === 'GRANTED') {
      // Republicar um comando antigo nao pode abrir a porta se o terminal/local saiu de operacao.
      if (!(await this.access.canDispatch(input.terminalId))) {
        throw new ServiceUnavailableError('Terminal indisponivel no momento');
      }
      try {
        // Publica o comando gravado na decisao; nunca cria um prazo novo aqui.
        const published = await this.publish.execute({
          requestId: event.id,
          terminalId: input.terminalId,
          action: 'open',
          reason: 'authorized',
          decidedAt: new Date(event.occurredAt),
        });
        commandPublished = published.published;
      } catch (error) {
        if (error instanceof DomainError) throw error;
        // A autorizacao ja foi consumida junto com a intencao: o relay entrega, sem nova decisao.
        this.logger.warn('publicacao do comando adiada para o relay', {
          requestId: event.id,
          terminalId: input.terminalId,
          error: error instanceof Error ? error.message : String(error),
        });
      }
    }

    return {
      decision: event.decision,
      reason: event.reason,
      message: event.decision === 'GRANTED' ? 'Acesso autorizado' : `Acesso negado: ${event.reason}`,
      event,
      commandPublished,
    };
  }
}
