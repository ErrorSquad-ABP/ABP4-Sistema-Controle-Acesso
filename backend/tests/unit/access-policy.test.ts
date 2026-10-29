import { describe, expect, it } from 'vitest';
import { decideAccess } from '../../src/domain/access/access-policy.js';

const now = new Date('2026-10-26T12:00:00Z');
const terminal = {
  id: 'terminal-01', active: true,
  location: { id: 'local-01', name: 'Recepcao', active: true, latitude: -23, longitude: -45, radiusMeters: 100 },
};
const user = { id: 'user-01', name: 'Maria', role: 'RESIDENT' as const, active: true };
const authorization = {
  id: 'auth-01', userId: user.id, locationId: terminal.location.id,
  startsAt: new Date(now.getTime() - 1000), endsAt: new Date(now.getTime() + 1000),
  maxUses: 1, usedCount: 0, canceledAt: null,
};
const context = { terminal, user, authorizations: [authorization], credentialValid: true, method: 'NFC' as const, now };

describe('DT-03: decisao pelo local resolvido do terminal', () => {
  it('nega terminal desconhecido e local/terminal desativado', () => {
    expect(decideAccess({ ...context, terminal: null }).reason).toBe('UNKNOWN_TERMINAL');
    expect(decideAccess({ ...context, terminal: { ...terminal, active: false } }).reason).toBe('TERMINAL_INACTIVE');
    expect(decideAccess({ ...context, terminal: { ...terminal, location: { ...terminal.location, active: false } } }).reason)
      .toBe('TERMINAL_INACTIVE');
  });

  it('autoriza somente para o local mapeado', () => {
    expect(decideAccess(context)).toEqual({ action: 'open', reason: 'authorized', authorizationId: authorization.id, distanceMeters: null });
    expect(decideAccess({ ...context, authorizations: [{ ...authorization, locationId: 'outro-local' }] }).reason)
      .toBe('NO_AUTHORIZATION');
  });

  it.each([
    [{ canceledAt: now }, 'AUTHORIZATION_CANCELED'],
    [{ startsAt: new Date(now.getTime() + 1) }, 'AUTHORIZATION_NOT_STARTED'],
    [{ endsAt: new Date(now.getTime() - 1) }, 'AUTHORIZATION_EXPIRED'],
    [{ usedCount: 1 }, 'NO_USES_LEFT'],
  ])('nega autorizacao indisponivel: %s', (change, reason) => {
    expect(decideAccess({ ...context, authorizations: [{ ...authorization, ...change }] }).reason).toBe(reason);
  });

  it('nega credencial invalida e usuario inativo', () => {
    expect(decideAccess({ ...context, credentialValid: false }).reason).toBe('INVALID_CREDENTIAL');
    expect(decideAccess({ ...context, user: { ...user, active: false } }).reason).toBe('USER_INACTIVE');
  });

  it('QR usa as coordenadas do local do terminal e exige posicao', () => {
    expect(decideAccess({ ...context, method: 'QR', position: { latitude: -23, longitude: -45 } }).action).toBe('open');
    expect(decideAccess({ ...context, method: 'QR', position: { latitude: 0, longitude: 0 } }).reason).toBe('OUT_OF_RANGE');
    expect(decideAccess({ ...context, method: 'QR' }).reason).toBe('OUT_OF_RANGE');
  });

  it('geofence de 100 m: registra a distancia e nega alem do raio (US-20)', () => {
    const dentro = decideAccess({ ...context, method: 'QR', position: { latitude: -22.999551, longitude: -45 } });
    expect(dentro.action).toBe('open');
    expect(dentro.distanceMeters).toBeGreaterThan(45);
    expect(dentro.distanceMeters).toBeLessThan(55);

    const fora = decideAccess({ ...context, method: 'QR', position: { latitude: -22.998652, longitude: -45 } });
    expect(fora).toMatchObject({ action: 'deny', reason: 'OUT_OF_RANGE' });
    expect(fora.distanceMeters).toBeGreaterThan(140);
    expect(fora.distanceMeters).toBeLessThan(160);

    // Raio vem do local mapeado, nao de uma constante da politica.
    const raioMenor = { ...terminal, location: { ...terminal.location, radiusMeters: 40 } };
    expect(decideAccess({ ...context, terminal: raioMenor, method: 'QR', position: { latitude: -22.999551, longitude: -45 } }))
      .toMatchObject({ action: 'deny', reason: 'OUT_OF_RANGE' });
  });

  it('prefere autorizacao utilizavel quando outra esta cancelada', () => {
    expect(decideAccess({ ...context, authorizations: [{ ...authorization, id: 'cancelada', canceledAt: now }, authorization] }).action)
      .toBe('open');
  });
});
