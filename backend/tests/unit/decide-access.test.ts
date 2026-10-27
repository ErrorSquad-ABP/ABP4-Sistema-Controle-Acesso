import { describe, expect, it, vi } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import {
  IssueQrCredentialUseCase,
  ValidateQrCredentialUseCase,
} from '../../src/application/terminal/qr-credential.use-cases.js';
import type { AccessRepository, AccessTransaction } from '../../src/domain/ports/access-repository.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { COMMAND_TTL_MS } from '../../src/domain/terminal/messages.js';
import { FixedClock, NOW, SequentialIds, UUID_A } from '../support/terminal-fakes.js';

const TERMINAL = 'terminal-01';
const signer = new HmacQrTokenSigner('a'.repeat(64));

function setup(options: { terminal?: boolean } = {}) {
  const user = { id: 'user', name: 'Maria', role: 'RESIDENT' as const, active: true };
  const terminal = {
    id: TERMINAL,
    active: true,
    location: { id: 'local-01', name: 'Recepcao', active: true, latitude: -23, longitude: -45, radiusMeters: 100 },
  };
  const authorization = {
    id: 'autorizacao', userId: user.id, locationId: terminal.location.id,
    startsAt: new Date(NOW.getTime() - 1000), endsAt: new Date(NOW.getTime() + 1000),
    maxUses: 1, usedCount: 0, canceledAt: null,
  };
  const commands = new PendingCommands();
  const tx = {
    findEvent: vi.fn<AccessTransaction['findEvent']>().mockResolvedValue(null),
    findTerminal: vi.fn<AccessTransaction['findTerminal']>().mockResolvedValue(options.terminal === false ? null : terminal),
    findUser: vi.fn<AccessTransaction['findUser']>().mockResolvedValue(user),
    findCredential: vi.fn<AccessTransaction['findCredential']>().mockResolvedValue({
      id: 'credencial', user, validFrom: null, validUntil: null, revokedAt: null,
    }),
    findAuthorizations: vi.fn<AccessTransaction['findAuthorizations']>().mockResolvedValue([authorization]),
    consumeAuthorization: vi.fn<AccessTransaction['consumeAuthorization']>().mockResolvedValue(true),
    record: vi.fn<AccessTransaction['record']>().mockImplementation(async (event) => event),
    saveCommand: vi.fn<AccessTransaction['saveCommand']>().mockImplementation(async (command, requestId) =>
      commands.save(command, requestId)),
  };
  const repository: AccessRepository = {
    transaction: async (_requestId, work) => work(tx),
    ready: vi.fn(),
  };
  const clock = new FixedClock(NOW);
  const ids = new SequentialIds();
  const useCase = new DecideAccessUseCase(
    repository,
    clock,
    new ValidateQrCredentialUseCase(clock, signer),
    ids,
  );
  return { tx, commands, clock, ids, useCase };
}

const attempt = { id: UUID_A, terminalId: TERMINAL, method: 'NFC' as const, uid: '04a1b2c3' };

describe('decisao e auditoria transacional', () => {
  it('resolve local, normaliza UID, consome um uso e grava sem UID original', async () => {
    const { useCase, tx } = setup();
    const event = await useCase.execute(attempt);
    expect(tx.findCredential).toHaveBeenCalledWith(expect.not.stringContaining('04a1b2c3'));
    expect(tx.findAuthorizations).toHaveBeenCalledWith('user', 'local-01');
    expect(tx.consumeAuthorization).toHaveBeenCalledOnce();
    expect(event).toMatchObject({ decision: 'GRANTED', location: { id: 'local-01' }, reason: null });
    expect(JSON.stringify(event)).not.toContain('04a1b2c3');
  });

  it('terminal desconhecido gera auditoria com local nulo e nao gasta autorizacao', async () => {
    const { useCase, tx } = setup({ terminal: false });
    expect(await useCase.execute(attempt)).toMatchObject({
      decision: 'DENIED', reason: 'UNKNOWN_TERMINAL', location: null,
    });
    expect(tx.consumeAuthorization).not.toHaveBeenCalled();
    expect(tx.record).toHaveBeenCalledOnce();
    expect(tx.saveCommand).not.toHaveBeenCalled();
  });

  it('retentativa devolve evento persistido sem consumir de novo', async () => {
    const { useCase, tx } = setup();
    const saved = await useCase.execute(attempt);
    tx.findEvent.mockResolvedValue(saved);
    expect(await useCase.execute(attempt)).toBe(saved);
    expect(tx.record).toHaveBeenCalledOnce();
    expect(tx.consumeAuthorization).toHaveBeenCalledOnce();
  });

  it('recusa reusar o identificador da tentativa com outro usuario', async () => {
    const { useCase, tx } = setup();
    const saved = await useCase.execute({
      id: UUID_A, terminalId: TERMINAL, method: 'QR' as const, userId: 'user',
      qrToken: 'x', position: { latitude: -23, longitude: -45 },
    });
    tx.findEvent.mockResolvedValue(saved);
    await expect(
      useCase.execute({
        id: UUID_A, terminalId: TERMINAL, method: 'QR' as const, userId: 'outro',
        qrToken: 'x', position: { latitude: -23, longitude: -45 },
      }),
    ).rejects.toMatchObject({ code: 'CONFLICT' });
  });

  it('conflito no consumo nega em vez de abrir', async () => {
    const { useCase, tx } = setup();
    tx.consumeAuthorization.mockResolvedValue(false);
    expect(await useCase.execute(attempt)).toMatchObject({ decision: 'DENIED', reason: 'NO_USES_LEFT' });
  });

  it('QR expirado, de outro terminal e sem posicao sao negados', async () => {
    const { useCase, tx, clock } = setup();
    const grant = await useCase.execute(attempt);
    expect(grant.decision).toBe('GRANTED');
    const credential = new IssueQrCredentialUseCase(clock, new SequentialIds(), signer).execute(TERMINAL);
    const qrAttempt = {
      id: '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c11', terminalId: TERMINAL, method: 'QR' as const,
      userId: 'user', qrToken: credential.token, position: { latitude: -23, longitude: -45 },
    };
    expect(await useCase.execute(qrAttempt)).toMatchObject({ decision: 'GRANTED' });
    clock.date = new Date(credential.expiresAt);
    expect(await useCase.execute({ ...qrAttempt, id: '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c12' }))
      .toMatchObject({ decision: 'DENIED', reason: 'CREDENTIAL_EXPIRED' });
    expect(await useCase.execute({ ...qrAttempt, id: '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c13', qrToken: 'inventado' }))
      .toMatchObject({ decision: 'DENIED', reason: 'INVALID_CREDENTIAL' });
    clock.date = NOW;
    expect(await useCase.execute({ ...qrAttempt, id: '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c14', position: undefined }))
      .toMatchObject({ decision: 'DENIED', reason: 'OUT_OF_RANGE' });
    expect(tx.consumeAuthorization).toHaveBeenCalledTimes(2);
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

describe('DT-02: intencao de comando na mesma transacao da decisao', () => {
  it('grava o comando com prazo ancorado no instante da decisao', async () => {
    const { useCase, tx, commands } = setup();
    const event = await useCase.execute(attempt);
    expect(tx.saveCommand).toHaveBeenCalledOnce();

    const [command, requestId] = tx.saveCommand.mock.calls[0]!;
    expect(requestId).toBe(event.id);
    expect(command).toMatchObject({
      terminalId: TERMINAL,
      action: 'open',
      timestamp: event.occurredAt,
      expiresAt: new Date(NOW.getTime() + COMMAND_TTL_MS).toISOString(),
    });
    expect(await commands.findByRequestId(event.id)).toMatchObject({ commandId: command.commandId });
  });

  it('falha ao gravar o comando nao devolve concessao nem deixa o evento consultavel', async () => {
    const { useCase, tx } = setup();
    tx.saveCommand.mockRejectedValue(new Error('falha ao gravar comando'));

    await expect(useCase.execute(attempt)).rejects.toThrow('falha ao gravar comando');
    expect(tx.saveCommand).toHaveBeenCalledOnce();
  });

  it('decisao negada nao persiste intencao de abertura', async () => {
    const { useCase, tx } = setup({ terminal: false });
    await useCase.execute(attempt);
    expect(tx.saveCommand).not.toHaveBeenCalled();
  });
});
