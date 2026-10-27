import type { DecideAccessUseCase } from '../../application/access/decide-access.use-case.js';
import type { AccessDecider, AccessDecision } from '../../domain/ports/access-decider.js';
import type { AccessEventMessage } from '../../domain/terminal/messages.js';

/** Decisor real: a fonte da verdade e o PostgreSQL (DT-01), nunca um fallback permissivo. */
export class DatabaseAccessDecider implements AccessDecider {
  constructor(private readonly decideAccess: DecideAccessUseCase) {}

  async decide(event: AccessEventMessage): Promise<AccessDecision> {
    const record = await this.decideAccess.execute({
      id: event.messageId,
      terminalId: event.terminalId,
      method: 'NFC',
      uid: event.uid,
    });
    return {
      action: record.decision === 'GRANTED' ? 'open' : 'deny',
      reason: record.reason ?? 'authorized',
      decidedAt: new Date(record.occurredAt),
    };
  }
}
