import type { IdGenerator } from '../../domain/ports/id-generator.js';
import type { DecideAccessUseCase } from './decide-access.use-case.js';
import type { PublishCommandUseCase } from '../terminal/publish-command.use-case.js';

export class RequestQrAccessUseCase {
  constructor(private readonly decide: DecideAccessUseCase, private readonly publish: PublishCommandUseCase, private readonly ids: IdGenerator) {}

  async execute(input: { userId: string; terminalId: string; qrToken: string; position: { latitude: number; longitude: number } }) {
    const event = await this.decide.execute({ ...input, id: this.ids.uuid(), method: 'QR' });
    if (event.decision === 'GRANTED') {
      await this.publish.execute({ requestId: event.id, terminalId: input.terminalId, action: 'open', reason: 'authorized' });
    }
    return { decision: event.decision, reason: event.reason,
      message: event.decision === 'GRANTED' ? 'Acesso autorizado' : `Acesso negado: ${event.reason}`, event };
  }
}
