import type { AuthorizationStatus, AuthorizationView } from '../../domain/authorizations/authorization.js';
import type { AuthorizationRepository } from '../../domain/ports/authorization-repository.js';
import type { Clock } from '../../domain/ports/clock.js';

export interface ListMyAuthorizationsQuery {
  page: number;
  pageSize: number;
  status?: AuthorizationStatus | undefined;
}

export interface AuthorizationPage {
  items: AuthorizationView[];
  page: number;
  pageSize: number;
  total: number;
}

/** Minhas autorizacoes: o userId vem do token, nunca da query. */
export class ListMyAuthorizationsUseCase {
  constructor(
    private readonly authorizations: AuthorizationRepository,
    private readonly clock: Clock,
  ) {}

  async execute(userId: string, query: ListMyAuthorizationsQuery): Promise<AuthorizationPage> {
    const { items, total } = await this.authorizations.listForUser({
      userId,
      page: query.page,
      pageSize: query.pageSize,
      status: query.status,
      now: this.clock.now(),
    });
    return { items, page: query.page, pageSize: query.pageSize, total };
  }
}
