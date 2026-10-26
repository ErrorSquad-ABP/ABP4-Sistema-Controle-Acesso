import { deriveAuthorizationStatus, presentAuthorization } from '../../domain/authorizations/authorization.js';
import { ConflictError, NotFoundError } from '../../domain/errors/domain-error.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { AuthorizationRepository } from '../../domain/ports/authorization-repository.js';

export interface CancelAuthorizationInput { id: string; reason?: string; }

export class CancelAuthorizationUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}

  async execute(input: CancelAuthorizationInput) {
    const record = await this.repository.findById(input.id);
    if (!record) throw new NotFoundError('Autorizacao nao encontrada');
    const now = this.clock.now();
    const status = deriveAuthorizationStatus(record, now);
    if (status === 'CANCELED' || status === 'EXPIRED') {
      throw new ConflictError('Autorizacao cancelada ou expirada nao pode ser cancelada');
    }
    const updated = await this.repository.cancelIfUnchanged(record, now, input.reason?.trim() || null);
    if (!updated) throw new ConflictError('Autorizacao foi alterada por outra operacao');
    return presentAuthorization(updated, now);
  }
}
