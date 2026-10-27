import type {
  AccessEventFilters,
  AccessEventPageQuery,
  AccessEventRepository,
} from '../../domain/ports/access-event-repository.js';

/** Minhas autorizacoes: o userId vem do token, nunca da query. */
export class ListMyAccessEventsUseCase {
  constructor(private readonly events: AccessEventRepository) {}

  execute(userId: string, query: Pick<AccessEventPageQuery, 'page' | 'pageSize' | 'from' | 'to'>) {
    const filters: AccessEventFilters = { userId, page: query.page, pageSize: query.pageSize };
    if (query.from) filters.from = new Date(query.from);
    if (query.to) filters.to = new Date(query.to);
    return this.events.list(filters);
  }
}
