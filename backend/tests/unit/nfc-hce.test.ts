import { describe, expect, it, vi } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import { IssueNfcCredentialUseCase } from '../../src/application/terminal/issue-nfc-credential.use-case.js';
import type { ValidateQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import type { AccessCredential, AccessRepository, AccessTransaction } from '../../src/domain/ports/access-repository.js';
import { hashCredential } from '../../src/shared/credential-hash.js';
import { parsePayload } from '../../src/infrastructure/mqtt/payload-parser.js';
import { FixedClock, NOW, SequentialIds } from '../support/terminal-fakes.js';

const TERMINAL = 'terminal-01';
const USER = '2b0f2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';

function setupCredential(consumedAt: Date | null = null, type: 'NFC' | 'NFC_HCE' = 'NFC_HCE') {
  const clock = new FixedClock(NOW);
  const credential: AccessCredential = {
    id: 'prova-hce',
    type,
    user: { id: USER, name: 'Maria', role: 'RESIDENT', active: true },
    validFrom: null,
    validUntil: new Date(NOW.getTime() + 60_000),
    revokedAt: null,
    consumedAt,
  };
  const state = { consumed: false };
  const tx = {
    findEvent: vi.fn().mockResolvedValue(null),
    findTerminal: vi.fn().mockResolvedValue({
      id: TERMINAL,
      active: true,
      qrCode: null,
      location: { id: 'local', name: 'Recepcao', active: true, latitude: 0, longitude: 0, radiusMeters: 100 },
    }),
    findUser: vi.fn().mockResolvedValue(credential.user),
    findCredential: vi.fn().mockImplementation(async (hash: string) =>
      hash === hashCredential('a'.repeat(32)) || hash === hashCredential('04A1B2C3') ? credential : null),
    findAuthorizations: vi.fn().mockResolvedValue([{
      id: 'autorizacao', userId: USER, locationId: 'local',
      startsAt: new Date(NOW.getTime() - 60_000), endsAt: new Date(NOW.getTime() + 60_000),
      maxUses: 5, usedCount: 0, canceledAt: null,
    }]),
    consumeAuthorization: vi.fn().mockResolvedValue(true),
    consumeCredential: vi.fn().mockImplementation(async () => {
      if (state.consumed) return false;
      state.consumed = true;
      return true;
    }),
    record: vi.fn().mockImplementation(async (event) => event),
    saveCommand: vi.fn().mockImplementation(async (command) => command),
  } satisfies AccessTransaction;
  const repository = {
    transaction: async <T>(_id: string, work: (tx: AccessTransaction) => Promise<T>) => work(tx),
    ready: vi.fn(),
    canDispatch: vi.fn().mockResolvedValue(true),
    findTerminalIdByQrCode: vi.fn(),
    listQrTerminalCodes: vi.fn(),
    saveNfcCredential: vi.fn(),
  } as unknown as AccessRepository;
  const decide = new DecideAccessUseCase(repository, clock, {} as ValidateQrCredentialUseCase, new SequentialIds());
  return { decide, tx, state, clock };
}

describe('NFC do celular (HCE)', () => {
  it('emite prova de 32 hex, guarda so o hash e expira em 60 s', async () => {
    const clock = new FixedClock(NOW);
    const saveNfcCredential = vi.fn().mockResolvedValue(undefined);
    const useCase = new IssueNfcCredentialUseCase(
      { saveNfcCredential } as unknown as AccessRepository,
      clock,
      new SequentialIds(),
    );

    const issued = await useCase.execute(USER);

    expect(issued.token).toMatch(/^[0-9a-f]{32}$/);
    expect(issued.expiresAt).toBe(new Date(NOW.getTime() + 60_000).toISOString());
    expect(saveNfcCredential).toHaveBeenCalledWith(expect.objectContaining({
      userId: USER,
      valueHash: hashCredential(issued.token),
      validFrom: NOW,
      validUntil: new Date(NOW.getTime() + 60_000),
    }));
    expect(JSON.stringify(saveNfcCredential.mock.calls)).not.toContain(issued.token);
  });

  it('consome a prova uma unica vez', async () => {
    const { decide, state } = setupCredential();
    const first = await decide.execute({
      id: '11111111-1111-4111-8111-111111111111',
      terminalId: TERMINAL,
      method: 'NFC',
      nfcToken: 'a'.repeat(32),
      occurredAt: NOW,
    });
    expect(first.decision).toBe('GRANTED');
    expect(state.consumed).toBe(true);

    const second = await decide.execute({
      id: '22222222-2222-4222-8222-222222222222',
      terminalId: TERMINAL,
      method: 'NFC',
      nfcToken: 'a'.repeat(32),
      occurredAt: NOW,
    });
    expect(second.decision).toBe('DENIED');
    expect(second.reason).toBe('INVALID_CREDENTIAL');
  });

  it('prova ja consumida nao consome autorizacao', async () => {
    const { decide, tx } = setupCredential(new Date(NOW.getTime() - 1000));
    const result = await decide.execute({
      id: '33333333-3333-4333-8333-333333333333',
      terminalId: TERMINAL,
      method: 'NFC',
      nfcToken: 'a'.repeat(32),
      occurredAt: NOW,
    });
    expect(result).toMatchObject({ decision: 'DENIED', reason: 'INVALID_CREDENTIAL' });
    expect(tx.consumeAuthorization).not.toHaveBeenCalled();
  });

  it('tag NFC fisica continua usando o tipo NFC', async () => {
    const { decide, state } = setupCredential(null, 'NFC');
    const result = await decide.execute({
      id: '44444444-4444-4444-8444-444444444444',
      terminalId: TERMINAL,
      method: 'NFC',
      uid: '04A1B2C3',
      occurredAt: NOW,
    });
    expect(result.decision).toBe('GRANTED');
    expect(state.consumed).toBe(false);
  });

  it('parser aceita nfc_hce_read apenas com 32 hex minusculos', () => {
    const base = {
      v: 1,
      messageId: '55555555-5555-4555-8555-555555555555',
      terminalId: TERMINAL,
      timestamp: NOW.toISOString(),
      type: 'nfc_hce_read',
    };
    const valid = parsePayload('access-events', TERMINAL, JSON.stringify({ ...base, credentialToken: 'a'.repeat(32) }), { now: NOW });
    expect(valid.ok).toBe(true);
    expect(parsePayload('access-events', TERMINAL, JSON.stringify({ ...base, credentialToken: 'A'.repeat(32) }), { now: NOW }).ok).toBe(false);
    expect(parsePayload('access-events', TERMINAL, JSON.stringify({ ...base, credentialToken: 'a'.repeat(31) }), { now: NOW }).ok).toBe(false);
  });
});
