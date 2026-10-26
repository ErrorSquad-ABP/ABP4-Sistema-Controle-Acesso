import { describe, expect, it } from 'vitest';
import type { AuthorizationRecord } from '../../src/domain/authorizations/authorization.js';
import { ConflictError, NotFoundError } from '../../src/domain/errors/domain-error.js';
import type { Clock } from '../../src/domain/ports/clock.js';
import type {
  AuthorizationFilters,
  AuthorizationPageResult,
  AuthorizationRepository,
} from '../../src/domain/ports/authorization-repository.js';
import { CancelAuthorizationUseCase } from '../../src/application/authorizations/cancel-authorization.use-case.js';
import { GetAuthorizationUseCase } from '../../src/application/authorizations/get-authorization.use-case.js';
import { ListAuthorizationsUseCase } from '../../src/application/authorizations/list-authorizations.use-case.js';

const now = new Date('2026-10-26T12:00:00.000Z');
const sample = (id: string, overrides: Partial<AuthorizationRecord> = {}): AuthorizationRecord => ({
  id,
  userId: 'user-1', user: { id: 'user-1', name: 'Maria', role: 'VISITOR' },
  locationId: 'location-1', location: { id: 'location-1', name: 'Portaria' },
  startsAt: new Date('2026-10-26T10:00:00.000Z'), endsAt: new Date('2026-10-26T14:00:00.000Z'),
  maxUses: 3, usedCount: 0, canceledAt: null, cancelReason: null,
  createdAt: new Date('2026-10-25T00:00:00.000Z'), updatedAt: new Date('2026-10-25T00:00:00.000Z'),
  ...overrides,
});

class FixedClock implements Clock { now(): Date { return new Date(now); } }

class FakeAuthorizationRepository implements AuthorizationRepository {
  records = [sample('a'), sample('b', { startsAt: new Date('2026-10-27T00:00:00Z') }),
    sample('c', { endsAt: new Date('2026-10-25T00:00:00Z') }),
    sample('d', { canceledAt: new Date('2026-10-25T00:00:00Z') }),
    sample('e', { usedCount: 3 })];
  lastFilters?: AuthorizationFilters;
  lastCancellation?: { id: string; canceledAt: Date; reason: string | null };
  cancelConflict = false;

  async list(filters: AuthorizationFilters): Promise<AuthorizationPageResult> {
    this.lastFilters = filters;
    let found = this.records.filter((r) => (!filters.userId || r.userId === filters.userId)
      && (!filters.locationId || r.locationId === filters.locationId)
      && (!filters.from || r.endsAt >= filters.from)
      && (!filters.to || r.startsAt <= filters.to));
    if (filters.status) {
      found = found.filter((r) => {
        if (r.canceledAt) return filters.status === 'CANCELED';
        if (r.usedCount >= r.maxUses || filters.now > r.endsAt) return filters.status === 'EXPIRED';
        if (filters.now < r.startsAt) return filters.status === 'SCHEDULED';
        return filters.status === 'ACTIVE';
      });
    }
    const total = found.length;
    const offset = (filters.page - 1) * filters.pageSize;
    return { items: found.slice(offset, offset + filters.pageSize), total };
  }
  async findById(id: string) { return this.records.find((r) => r.id === id) ?? null; }
  async cancelIfUnchanged(record: AuthorizationRecord, canceledAt: Date, cancelReason: string | null) {
    if (this.cancelConflict) return null;
    this.lastCancellation = { id: record.id, canceledAt, reason: cancelReason };
    const updated = { ...record, canceledAt, cancelReason, updatedAt: canceledAt };
    this.records = this.records.map((r) => r.id === record.id ? updated : r);
    return updated;
  }
}

describe('authorization use cases', () => {
  it('passes filters and derives status using one clock value; total and page come from repository', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new ListAuthorizationsUseCase(repository, new FixedClock());
    const result = await useCase.execute({ userId: 'user-1', locationId: 'location-1', status: 'ACTIVE',
      from: new Date('2026-10-26T00:00:00Z'), to: new Date('2026-10-26T23:59:59Z'), page: 1, pageSize: 2 });
    expect(repository.lastFilters).toMatchObject({ userId: 'user-1', locationId: 'location-1', status: 'ACTIVE', page: 1, pageSize: 2, now });
    expect(result).toMatchObject({ page: 1, pageSize: 2, total: 1 });
    expect(result.items[0]).toMatchObject({ id: 'a', status: 'ACTIVE', remainingUses: 3 });
  });

  it('derives all four states with priority for canceled and expired', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new ListAuthorizationsUseCase(repository, new FixedClock());
    const statuses = await Promise.all(['ACTIVE', 'SCHEDULED', 'EXPIRED', 'CANCELED'].map(async (status) =>
      (await useCase.execute({ status: status as 'ACTIVE', page: 1, pageSize: 20 })).items.map((r) => r.status)));
    expect(statuses).toEqual([['ACTIVE'], ['SCHEDULED'], ['EXPIRED', 'EXPIRED'], ['CANCELED']]);
  });

  it('returns details and raises NotFoundError when missing', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new GetAuthorizationUseCase(repository, new FixedClock());
    await expect(useCase.execute('missing')).rejects.toBeInstanceOf(NotFoundError);
    expect(await useCase.execute('a')).toMatchObject({ id: 'a', status: 'ACTIVE' });
  });

  it('cancels with optional trimmed reason and stores timestamp', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new CancelAuthorizationUseCase(repository, new FixedClock());
    expect(await useCase.execute({ id: 'a', reason: ' Mudou de ideia ' })).toMatchObject({ status: 'CANCELED', cancelReason: 'Mudou de ideia' });
    expect(repository.lastCancellation).toEqual({ id: 'a', canceledAt: now, reason: 'Mudou de ideia' });
    await expect(useCase.execute({ id: 'a' })).rejects.toBeInstanceOf(ConflictError);
  });

  it('cancels without reason and rejects expired or concurrently changed authorizations', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new CancelAuthorizationUseCase(repository, new FixedClock());
    await useCase.execute({ id: 'b' });
    expect(repository.lastCancellation?.reason).toBeNull();
    await expect(useCase.execute({ id: 'c' })).rejects.toBeInstanceOf(ConflictError);
    repository.cancelConflict = true;
    await expect(useCase.execute({ id: 'a' })).rejects.toBeInstanceOf(ConflictError);
    await expect(useCase.execute({ id: 'missing' })).rejects.toBeInstanceOf(NotFoundError);
  });
});
