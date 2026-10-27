import { describe, expect, it, vi } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import type { AccessRepository, AccessTransaction } from '../../src/domain/ports/access-repository.js';
import { FixedClock, NOW, UUID_A } from '../support/terminal-fakes.js';

function setup() {
  const user = { id: 'user', name: 'Maria', role: 'RESIDENT' as const, active: true };
  const terminal = { id: 'terminal-01', active: true,
    location: { id: 'local-01', name: 'Recepcao', active: true, latitude: -23, longitude: -45, radiusMeters: 100 } };
  const authorization = { id: 'autorizacao', userId: user.id, locationId: terminal.location.id,
    startsAt: new Date(NOW.getTime()-1000), endsAt: new Date(NOW.getTime()+1000), maxUses: 1, usedCount: 0, canceledAt: null };
  const tx = {
    findEvent: vi.fn<AccessTransaction['findEvent']>().mockResolvedValue(null),
    findTerminal: vi.fn<AccessTransaction['findTerminal']>().mockResolvedValue(terminal),
    findUser: vi.fn<AccessTransaction['findUser']>().mockResolvedValue(user),
    findCredential: vi.fn<AccessTransaction['findCredential']>().mockResolvedValue({ id: 'credencial', user, validFrom: null, validUntil: null, revokedAt: null }),
    findQrToken: vi.fn<AccessTransaction['findQrToken']>().mockResolvedValue(null),
    findAuthorizations: vi.fn<AccessTransaction['findAuthorizations']>().mockResolvedValue([authorization]),
    consumeAuthorization: vi.fn<AccessTransaction['consumeAuthorization']>().mockResolvedValue(true),
    record: vi.fn<AccessTransaction['record']>().mockImplementation(async (event) => event),
  };
  const repository: AccessRepository = {
    transaction: async (_id, work) => work(tx), findUser: tx.findUser,
    list: vi.fn(), saveQrToken: vi.fn(),
  };
  const hasher = { hash: vi.fn((value: string) => `hash:${value}`) };
  return { tx, hasher, useCase: new DecideAccessUseCase(repository, new FixedClock(NOW), hasher) };
}
const attempt = { id: UUID_A, terminalId: 'terminal-01', method: 'NFC' as const, uid: '04a1b2c3' };

describe('decisao e auditoria transacional', () => {
  it('resolve local, normaliza UID, consome um uso e grava sem UID original', async () => {
    const { useCase, tx, hasher } = setup();
    const event = await useCase.execute(attempt);
    expect(hasher.hash).toHaveBeenCalledWith('04A1B2C3');
    expect(tx.findAuthorizations).toHaveBeenCalledWith('user', 'local-01');
    expect(tx.consumeAuthorization).toHaveBeenCalledOnce();
    expect(event).toMatchObject({ decision: 'GRANTED', location: { id: 'local-01' }, reason: null });
    expect(JSON.stringify(event)).not.toContain('04a1b2c3');
  });

  it('terminal desconhecido gera auditoria com local nulo e nao gasta autorizacao', async () => {
    const { useCase, tx } = setup();
    tx.findTerminal.mockResolvedValue(null);
    expect(await useCase.execute(attempt)).toMatchObject({ decision: 'DENIED', reason: 'UNKNOWN_TERMINAL', location: null });
    expect(tx.consumeAuthorization).not.toHaveBeenCalled();
    expect(tx.record).toHaveBeenCalledOnce();
  });

  it('retentativa devolve evento persistido sem consumir de novo', async () => {
    const { useCase, tx } = setup();
    const saved = await useCase.execute(attempt);
    tx.findEvent.mockResolvedValue(saved);
    expect(await useCase.execute(attempt)).toBe(saved);
    expect(tx.record).toHaveBeenCalledOnce();
    expect(tx.consumeAuthorization).toHaveBeenCalledOnce();
  });

  it('conflito no consumo nega em vez de abrir', async () => {
    const { useCase, tx } = setup();
    tx.consumeAuthorization.mockResolvedValue(false);
    expect(await useCase.execute(attempt)).toMatchObject({ decision: 'DENIED', reason: 'NO_USES_LEFT' });
  });

  it('QR expirado e QR de outro terminal sao negados', async () => {
    const { useCase, tx } = setup();
    tx.findQrToken.mockResolvedValue({ terminalId: 'terminal-01', expiresAt: NOW });
    const input = { id: UUID_A, terminalId: 'terminal-01', method: 'QR' as const, userId: 'user', qrToken: 'token', position: { latitude: -23, longitude: -45 } };
    expect(await useCase.execute(input)).toMatchObject({ decision: 'DENIED', reason: 'CREDENTIAL_EXPIRED' });
    tx.findQrToken.mockResolvedValue({ terminalId: 'outro-terminal', expiresAt: new Date(NOW.getTime()+10_000) });
    expect(await useCase.execute(input)).toMatchObject({ decision: 'DENIED', reason: 'INVALID_CREDENTIAL' });
    expect(tx.consumeAuthorization).not.toHaveBeenCalled();
  });

  it('erro na persistencia impede retornar concessao', async () => {
    const { useCase, tx } = setup();
    tx.record.mockRejectedValue(new Error('banco indisponivel'));
    await expect(useCase.execute(attempt)).rejects.toThrow('banco indisponivel');
  });

  it('nega credencial revogada e fora da validade', async () => {
    const { useCase, tx } = setup();
    const credential = (await tx.findCredential(''))!;
    tx.findCredential.mockResolvedValue({ ...credential, revokedAt: NOW });
    expect(await useCase.execute(attempt)).toMatchObject({ decision: 'DENIED', reason: 'INVALID_CREDENTIAL' });
    tx.findCredential.mockResolvedValue({ ...credential, validUntil: NOW });
    expect(await useCase.execute(attempt)).toMatchObject({ decision: 'DENIED', reason: 'CREDENTIAL_EXPIRED' });
  });
});
