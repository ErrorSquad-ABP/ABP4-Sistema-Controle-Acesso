import type { AccessQuery, AccessRepository } from '../../domain/ports/access-repository.js';

export class ListAccessEventsUseCase {
  constructor(private readonly repository: AccessRepository) {}
  execute(query: AccessQuery) { return this.repository.list(query); }
}
