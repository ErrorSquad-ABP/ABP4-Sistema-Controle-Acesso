import type { AccessEventView } from '../../src/domain/ports/access-event-repository.js';
import type {
  AccessEventFilters,
  AccessEventRepository,
} from '../../src/domain/ports/access-event-repository.js';

export class InMemoryAccessEventRepository implements AccessEventRepository {
  constructor(private readonly events: AccessEventView[] = []) {}

  async list(filters: AccessEventFilters) {
    const from = filters.from?.getTime();
    const to = filters.to?.getTime();
    const filtered = this.events
      .filter((event) => !filters.userId || event.user?.id === filters.userId)
      .filter((event) => !filters.locationId || event.location.id === filters.locationId)
      .filter((event) => !filters.method || event.method === filters.method)
      .filter((event) => !filters.decision || event.decision === filters.decision)
      .filter((event) => from === undefined || Date.parse(event.occurredAt) >= from)
      .filter((event) => to === undefined || Date.parse(event.occurredAt) <= to)
      .sort((a, b) => b.occurredAt.localeCompare(a.occurredAt) || b.id.localeCompare(a.id));

    const start = (filters.page - 1) * filters.pageSize;
    return { items: filtered.slice(start, start + filters.pageSize), total: filtered.length };
  }
}
