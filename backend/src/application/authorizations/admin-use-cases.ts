import { authorizationStatus, toAuthorizationView, type AuthorizationView } from '../../domain/authorizations/authorization.js';
import { ConflictError, NotFoundError } from '../../domain/errors/domain-error.js';
import type { AuthorizationAdminFilters, AuthorizationRepository } from '../../domain/ports/authorization-repository.js';
import type { Clock } from '../../domain/ports/clock.js';

export class ListAuthorizationsUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}
  async execute(query: Omit<AuthorizationAdminFilters, 'now'>) {
    const { items, total } = await this.repository.list({ ...query, now: this.clock.now() });
    return { items, page: query.page, pageSize: query.pageSize, total };
  }
}

export class GetAuthorizationUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}
  async execute(id: string): Promise<AuthorizationView> {
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Autorizacao nao encontrada');
    return toAuthorizationView(record, this.clock.now());
  }
}

export class CreateAuthorizationUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}
  async execute(input: { userId: string; locationId: string; startsAt: string; endsAt: string; maxUses: number }, createdById: string) {
    const record = await this.repository.create({
      ...input,
      startsAt: new Date(input.startsAt),
      endsAt: new Date(input.endsAt),
      createdById,
    });
    return toAuthorizationView(record, this.clock.now());
  }
}

export class CancelAuthorizationUseCase {
  constructor(private readonly repository: AuthorizationRepository, private readonly clock: Clock) {}
  async execute(id: string, reason?: string): Promise<AuthorizationView> {
    const now = this.clock.now();
    const record = await this.repository.findById(id);
    if (!record) throw new NotFoundError('Autorizacao nao encontrada');
    const status = authorizationStatus(record, now);
    if (status === 'CANCELED' || status === 'EXPIRED') throw new ConflictError('Autorizacao cancelada ou expirada nao pode ser cancelada');
    const canceled = await this.repository.cancel(id, now, reason ?? null);
    if (!canceled) throw new NotFoundError('Autorizacao nao encontrada');
    return toAuthorizationView(canceled, now);
  }
}
