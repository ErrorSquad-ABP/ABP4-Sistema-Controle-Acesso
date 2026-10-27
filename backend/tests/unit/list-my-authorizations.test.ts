import { describe, expect, it } from 'vitest';
import { ListMyAuthorizationsUseCase } from '../../src/application/authorizations/list-my-authorizations.use-case.js';
import { authorizationStatus, type AuthorizationRecord } from '../../src/domain/authorizations/authorization.js';
import { InMemoryAuthorizationRepository } from '../support/in-memory-authorizations.js';
import { FixedClock } from '../support/in-memory-repositories.js';

const now = new Date('2026-10-27T12:00:00.000Z');

function record(id: string, overrides: Partial<AuthorizationRecord> = {}): AuthorizationRecord {
  return {
    id,
    user: { id: 'u1', name: 'Maria', role: 'RESIDENT' },
    location: { id: 'l1', name: 'Recepcao' },
    startsAt: new Date('2026-10-27T11:00:00.000Z'),
    endsAt: new Date('2026-10-27T13:00:00.000Z'),
    maxUses: 5,
    usedCount: 1,
    canceledAt: null,
    cancelReason: null,
    createdAt: new Date('2026-10-26T10:00:00.000Z'),
    ...overrides,
  };
}

const mine = [
  record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae01', { startsAt: new Date('2026-10-27T13:00:00.000Z'), endsAt: new Date('2026-10-27T14:00:00.000Z') }),
  record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae02', { startsAt: new Date('2026-10-27T11:30:00.000Z') }),
  record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae03', { maxUses: 2, usedCount: 2 }),
  record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae04', { startsAt: new Date('2026-10-27T09:00:00.000Z'), endsAt: new Date('2026-10-27T10:00:00.000Z') }),
  record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae05', { startsAt: new Date('2026-10-27T10:00:00.000Z'), canceledAt: new Date('2026-10-27T08:00:00.000Z') }),
];
const other = record('6ec0bd7f-11c0-43da-975e-2a8ad9ebae06', {
  user: { id: 'u2', name: 'Bia', role: 'VISITOR' },
});

function build() {
  return new ListMyAuthorizationsUseCase(
    new InMemoryAuthorizationRepository([...mine, other]),
    new FixedClock(now),
  );
}

describe('ListMyAuthorizationsUseCase', () => {
  it('devolve so as autorizacoes do usuario logado', async () => {
    const page = await build().execute('u1', { page: 1, pageSize: 20 });

    expect(page.total).toBe(5);
    expect(page.items.every((item) => item.user.id === 'u1')).toBe(true);
  });

  it('ordena por startsAt desc e id desc', async () => {
    const page = await build().execute('u1', { page: 1, pageSize: 20 });

    expect(page.items.map((item) => item.id)).toEqual([
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae01',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae02',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae03',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae05',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae04',
    ]);
  });

  it('calcula status, remainingUses e datas em UTC', async () => {
    const page = await build().execute('u1', { page: 1, pageSize: 20 });
    const byStatus = Object.fromEntries(page.items.map((item) => [item.status, item]));

    expect(byStatus.ACTIVE).toMatchObject({ remainingUses: 4, canceledAt: null });
    expect(byStatus.SCHEDULED?.startsAt).toBe('2026-10-27T13:00:00.000Z');
    expect(byStatus.EXPIRED).toBeDefined();
    expect(page.items.find((item) => item.id.endsWith('ae05'))).toMatchObject({ status: 'CANCELED' });
    expect(page.items.find((item) => item.id.endsWith('ae03'))).toMatchObject({ status: 'EXPIRED', remainingUses: 0 });
  });

  it('filtra pela situacao calculada', async () => {
    const list = build();

    expect((await list.execute('u1', { page: 1, pageSize: 20, status: 'ACTIVE' })).items.map((i) => i.id)).toEqual([
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae02',
    ]);
    expect((await list.execute('u1', { page: 1, pageSize: 20, status: 'EXPIRED' })).total).toBe(2);
    expect((await list.execute('u1', { page: 1, pageSize: 20, status: 'SCHEDULED' })).total).toBe(1);
    expect((await list.execute('u1', { page: 1, pageSize: 20, status: 'CANCELED' })).total).toBe(1);
  });

  it('pagina mantendo o total do filtro', async () => {
    const page = await build().execute('u1', { page: 2, pageSize: 2 });

    expect(page).toMatchObject({ page: 2, pageSize: 2, total: 5 });
    expect(page.items.map((item) => item.id)).toEqual([
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae03',
      '6ec0bd7f-11c0-43da-975e-2a8ad9ebae05',
    ]);
  });

  it('status da borda (exatamente no fim) e EXPIRED', () => {
    expect(authorizationStatus(record('x', { endsAt: now }), now)).toBe('EXPIRED');
  });
});
