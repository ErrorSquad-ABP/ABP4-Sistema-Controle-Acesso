import { describe, expect, it } from 'vitest';
import {
  authorizationStatus,
  remainingUses,
  toAuthorizationView,
  type AuthorizationRecord,
} from '../../src/domain/authorizations/authorization.js';

const now = new Date('2026-10-27T12:00:00.000Z');

function record(overrides: Partial<AuthorizationRecord> = {}): AuthorizationRecord {
  return {
    id: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b',
    user: { id: '7c9e6679-7425-40de-944b-e07fc1f90ae7', name: 'Maria', role: 'RESIDENT' },
    location: { id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427', name: 'Recepcao' },
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

describe('situacao calculada da autorizacao', () => {
  it('ACTIVE dentro da janela e com usos restantes', () => {
    expect(authorizationStatus(record(), now)).toBe('ACTIVE');
  });

  it('SCHEDULED antes do inicio e ACTIVE exatamente no inicio', () => {
    expect(authorizationStatus(record({ startsAt: new Date('2026-10-27T12:00:01.000Z') }), now)).toBe('SCHEDULED');
    expect(authorizationStatus(record({ startsAt: now }), now)).toBe('ACTIVE');
  });

  it('EXPIRED exatamente no fim e depois dele', () => {
    expect(authorizationStatus(record({ endsAt: now }), now)).toBe('EXPIRED');
    expect(authorizationStatus(record({ endsAt: new Date('2026-10-27T11:59:59.000Z') }), now)).toBe('EXPIRED');
  });

  it('EXPIRED quando os usos acabaram, mesmo dentro da janela', () => {
    expect(authorizationStatus(record({ maxUses: 3, usedCount: 3 }), now)).toBe('EXPIRED');
    expect(authorizationStatus(record({ maxUses: 3, usedCount: 2 }), now)).toBe('ACTIVE');
  });

  it('CANCELED vence as demais regras', () => {
    const canceledAt = new Date('2026-10-27T10:00:00.000Z');
    expect(authorizationStatus(record({ canceledAt }), now)).toBe('CANCELED');
    expect(
      authorizationStatus(record({ canceledAt, startsAt: new Date('2026-12-01T00:00:00.000Z') }), now),
    ).toBe('CANCELED');
    expect(authorizationStatus(record({ canceledAt, endsAt: new Date('2026-10-26T00:00:00.000Z') }), now)).toBe(
      'CANCELED',
    );
  });

  it('remainingUses nunca fica negativo', () => {
    expect(remainingUses(record({ maxUses: 5, usedCount: 1 }))).toBe(4);
    expect(remainingUses(record({ maxUses: 5, usedCount: 5 }))).toBe(0);
    expect(remainingUses(record({ maxUses: 5, usedCount: 7 }))).toBe(0);
  });
});

describe('toAuthorizationView', () => {
  it('serializa datas em UTC e inclui status/remainingUses', () => {
    const view = toAuthorizationView(
      record({ canceledAt: new Date('2026-10-27T10:00:00.000Z'), cancelReason: 'Visita remarcada' }),
      now,
    );

    expect(view).toMatchObject({
      status: 'CANCELED',
      remainingUses: 4,
      canceledAt: '2026-10-27T10:00:00.000Z',
      cancelReason: 'Visita remarcada',
      createdAt: '2026-10-26T10:00:00.000Z',
    });
    expect(view.startsAt).toBe('2026-10-27T11:00:00.000Z');
    expect(view.canceledAt).toMatch(/Z$/);
  });

  it('devolve canceledAt null quando nao cancelada', () => {
    expect(toAuthorizationView(record(), now).canceledAt).toBeNull();
  });
});
