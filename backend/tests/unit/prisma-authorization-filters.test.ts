import { describe, expect, it } from 'vitest';
import { PrismaAuthorizationRepository } from '../../src/infrastructure/repositories/prisma-authorization-repository.js';
import { createFakePrismaAuthorization, type FakeAuthorizationRow } from '../support/fake-prisma-authorizations.js';

const now = new Date('2026-10-29T12:00:00.000Z');
const hour = 3_600_000;

const member = { id: 'a1000000-0000-4000-8000-000000000002', name: 'Moradora', role: 'RESIDENT' as const };
const location = { id: 'a1000000-0000-4000-8000-000000000003', name: 'Recepcao' };

function row(id: string, overrides: Partial<FakeAuthorizationRow> = {}): FakeAuthorizationRow {
  return {
    id,
    userId: member.id,
    locationId: location.id,
    startsAt: new Date(now.getTime() - 30 * 60_000),
    endsAt: new Date(now.getTime() + 30 * 60_000),
    maxUses: 5,
    usedCount: 1,
    canceledAt: null,
    cancelReason: null,
    createdAt: new Date(now.getTime() - 24 * hour),
    user: member,
    location,
    ...overrides,
  };
}

const ids = {
  activeInside: 'b0000000-0000-4000-8000-000000000001',
  activeOutside: 'b0000000-0000-4000-8000-000000000002',
  scheduledInside: 'b0000000-0000-4000-8000-000000000003',
  scheduledOutside: 'b0000000-0000-4000-8000-000000000004',
};

const rows = [
  row(ids.activeInside, {
    startsAt: new Date(now.getTime() - 30 * 60_000),
    endsAt: new Date(now.getTime() + 60 * 60_000),
  }),
  row(ids.activeOutside, {
    startsAt: new Date(now.getTime() - 5 * hour),
    endsAt: new Date(now.getTime() + 5 * hour),
  }),
  row(ids.scheduledInside, {
    startsAt: new Date(now.getTime() + 30 * 60_000),
    endsAt: new Date(now.getTime() + 2 * hour),
  }),
  row(ids.scheduledOutside, {
    startsAt: new Date(now.getTime() + 10 * hour),
    endsAt: new Date(now.getTime() + 12 * hour),
  }),
];

// Periodo de -1h a +3h: cada status tem uma linha dentro e outra fora da janela.
const from = new Date(now.getTime() - hour);
const to = new Date(now.getTime() + 3 * hour);

const repository = new PrismaAuthorizationRepository(createFakePrismaAuthorization(rows));

describe('PrismaAuthorizationRepository.list com periodo + status', () => {
  it('aplica o periodo junto do status ACTIVE', async () => {
    const page = await repository.list({ userId: member.id, from, to, status: 'ACTIVE', page: 1, pageSize: 20, now });

    expect(page.items.map((item) => item.id)).toEqual([ids.activeInside]);
    expect(page.total).toBe(1);
  });

  it('aplica o periodo junto do status SCHEDULED', async () => {
    const page = await repository.list({ userId: member.id, from, to, status: 'SCHEDULED', page: 1, pageSize: 20, now });

    expect(page.items.map((item) => item.id)).toEqual([ids.scheduledInside]);
    expect(page.total).toBe(1);
  });

  it('mantem o periodo quando nao ha status e conta o filtro', async () => {
    const page = await repository.list({ userId: member.id, from, to, page: 1, pageSize: 20, now });

    expect(page.items.map((item) => item.id)).toEqual([ids.scheduledInside, ids.activeInside]);
    expect(page.total).toBe(2);
  });
});
