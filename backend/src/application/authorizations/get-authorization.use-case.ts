import { presentAuthorization } from '../../domain/authorizations/authorization.js';
import { NotFoundError } from '../../domain/errors/domain-error.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { AuthorizationRepository } from '../../domain/ports/authorization-repository.js';

export class GetAuthorizationUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}

  async execute(id: string) {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Autorizacao nao encontrada');
    return presentAuthorization(record, this.clock.now());
  }
}
