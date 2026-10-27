import type { AccessDecider } from '../../domain/ports/access-decider.js';
import type { AccessEventMessage } from '../../domain/terminal/messages.js';
import type { DecideAccessUseCase } from '../../application/access/decide-access.use-case.js';

export class DatabaseAccessDecider implements AccessDecider {
  constructor(private readonly decideAccess: DecideAccessUseCase) {}
  async decide(event: AccessEventMessage) {
    const record = await this.decideAccess.execute({ id: event.messageId, terminalId: event.terminalId, method: 'NFC', uid: event.uid });
    return { action: record.decision === 'GRANTED' ? 'open' as const : 'deny' as const, reason: record.reason ?? 'authorized' };
  }
}
