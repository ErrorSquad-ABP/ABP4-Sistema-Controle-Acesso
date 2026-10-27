import type {
  AccessEventFilters,
  AccessEventPageQuery,
  AccessEventRepository,
} from '../../domain/ports/access-event-repository.js';

/** Historico completo (admin): todos os filtros do contrato. */
export class ListAccessEventsUseCase {
  constructor(private readonly events: AccessEventRepository) {}

  execute(query: AccessEventPageQuery) {
    const filters: AccessEventFilters = { page: query.page, pageSize: query.pageSize };
    if (query.userId) filters.userId = query.userId;
    if (query.locationId) filters.locationId = query.locationId;
    if (query.method) filters.method = query.method;
    if (query.decision) filters.decision = query.decision;
    if (query.from) filters.from = new Date(query.from);
    if (query.to) filters.to = new Date(query.to);
    return this.events.list(filters);
  }
}
