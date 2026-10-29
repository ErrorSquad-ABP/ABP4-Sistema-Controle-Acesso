import {
  authorizationStatus,
  toAuthorizationView,
  type AuthorizationRecord,
} from '../../src/domain/authorizations/authorization.js';
import type {
  AuthorizationAdminFilters,
  AuthorizationForUserFilters,
  AuthorizationRepository,
  NewAuthorization,
} from '../../src/domain/ports/authorization-repository.js';
import { ConflictError } from '../../src/domain/errors/domain-error.js';
import { randomUUID } from 'node:crypto';

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

  async list(filters: AuthorizationAdminFilters) {
    const filtered = this.authorizations
      .filter((a) => !filters.userId || a.user.id === filters.userId)
      .filter((a) => !filters.locationId || a.location.id === filters.locationId)
      .filter((a) => !filters.from || a.startsAt >= filters.from)
      .filter((a) => !filters.to || a.startsAt <= filters.to)
      .filter((a) => !filters.status || authorizationStatus(a, filters.now) === filters.status)
      .sort((a, b) => b.startsAt.getTime() - a.startsAt.getTime() || b.id.localeCompare(a.id));
    const start = (filters.page - 1) * filters.pageSize;
    return { items: filtered.slice(start, start + filters.pageSize).map((a) => toAuthorizationView(a, filters.now)), total: filtered.length };
  }

  async findById(id: string) { return this.authorizations.find((a) => a.id === id) ?? null; }

  async create(input: NewAuthorization) {
    const user = { id: input.userId, name: 'Pessoa', role: 'VISITOR' as const };
    const location = { id: input.locationId, name: 'Local' };
    const record: AuthorizationRecord = { id: randomUUID(), user, location, startsAt: input.startsAt, endsAt: input.endsAt, maxUses: input.maxUses, usedCount: 0, canceledAt: null, cancelReason: null, createdAt: new Date() };
    this.authorizations.push(record);
    return record;
  }

  async cancel(id: string, at: Date, reason: string | null) {
    const record = this.authorizations.find((a) => a.id === id);
    if (!record) return null;
    if (record.canceledAt || at >= record.endsAt || record.usedCount >= record.maxUses) {
      throw new ConflictError('Autorizacao cancelada ou expirada nao pode ser cancelada');
    }
    record.canceledAt = at;
    record.cancelReason = reason;
    return structuredClone(record);
  }
}
