import {
  authorizationStatus,
  toAuthorizationView,
  type AuthorizationRecord,
} from '../../src/domain/authorizations/authorization.js';
import type {
  AuthorizationForUserFilters,
  AuthorizationRepository,
} from '../../src/domain/ports/authorization-repository.js';

export class InMemoryAuthorizationRepository implements AuthorizationRepository {
  constructor(private readonly authorizations: AuthorizationRecord[] = []) {}

  async listForUser(filters: AuthorizationForUserFilters) {
    const filtered = this.authorizations
      .filter((authorization) => authorization.user.id === filters.userId)
      .filter(
        (authorization) =>
          filters.status === undefined || authorizationStatus(authorization, filters.now) === filters.status,
      )
      .sort(
        (a, b) =>
          b.startsAt.getTime() - a.startsAt.getTime() || b.id.localeCompare(a.id),
      );

    const start = (filters.page - 1) * filters.pageSize;
    return {
      items: filtered
        .slice(start, start + filters.pageSize)
        .map((authorization) => toAuthorizationView(authorization, filters.now)),
      total: filtered.length,
    };
  }
}
