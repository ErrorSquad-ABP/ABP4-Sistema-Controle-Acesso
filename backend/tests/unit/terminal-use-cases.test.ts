import { beforeEach, describe, expect, it, vi } from 'vitest';
import { HandleAccessEventUseCase } from '../../src/application/terminal/handle-access-event.use-case.js';
import { HandleAckUseCase } from '../../src/application/terminal/handle-ack.use-case.js';
import { PublishQrCodeUseCase } from '../../src/application/terminal/publish-qr-code.use-case.js';
import { ValidateQrCredentialUseCase, IssueQrCredentialUseCase } from '../../src/application/terminal/qr-credential.use-cases.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import type { AccessDecider } from '../../src/domain/ports/access-decider.js';
import type { AccessEventMessage, AckMessage } from '../../src/domain/terminal/messages.js';
import { QR_TTL_MS } from '../../src/domain/terminal/messages.js';
import { parsePayload } from '../../src/infrastructure/mqtt/payload-parser.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { SeenMessages } from '../../src/domain/terminal/seen-messages.js';
import {
  FixedClock,
  NOW,
  RecordingBus,
  SequentialIds,
  TERMINAL,
  UUID_A,
  UUID_B,
  envelope,
  silentLogger,
} from '../support/terminal-fakes.js';

const event: AccessEventMessage = { ...envelope(UUID_A), type: 'nfc_read', uid: '04A1B2C3' };

class FixedDecider implements AccessDecider {
  constructor(private readonly action: 'open' | 'deny') {}
  decide() {
    return Promise.resolve({ action: this.action, reason: 'teste', decidedAt: NOW });
  }
}

describe('terminal use cases', () => {
  let bus: RecordingBus;
  let clock: FixedClock;
  let pending: PendingCommands;
  let seen: SeenMessages;

  beforeEach(() => {
    bus = new RecordingBus();
    clock = new FixedClock(NOW);
    pending = new PendingCommands();
    seen = new SeenMessages();
  });

  const accessUseCase = (action: 'open' | 'deny' = 'open') =>
    new HandleAccessEventUseCase(
      new FixedDecider(action),
      bus,
      clock,
      new SequentialIds(),
      seen,
      pending,
      silentLogger,
    );

  describe('HandleAccessEventUseCase', () => {
    it('revalida frescor apos esperar pela reserva, sem decidir evento envelhecido na fila', async () => {
      const decide = vi.fn();
      const delayed = {
        run: async <T>(_id: string, work: () => Promise<T>) => {
          clock.date = new Date(NOW.getTime() + 30_000);
          return { duplicate: false as const, value: await work() };
        },
      };
      const useCase = new HandleAccessEventUseCase(
        { decide }, bus, clock, new SequentialIds(), delayed, pending, silentLogger,
      );
      expect(await useCase.execute(event)).toEqual({ status: 'stale' });
      expect(decide).not.toHaveBeenCalled();
      expect(bus.published).toHaveLength(0);
    });

    it('falha apos publicar libera reserva e retentativa reutiliza o mesmo comando', async () => {
      const logger = { ...silentLogger, info: () => { throw new Error('logger fora'); } };
      const useCase = new HandleAccessEventUseCase(
        new FixedDecider('open'), bus, clock, new SequentialIds(), seen, pending, logger,
      );
      await expect(useCase.execute(event)).rejects.toThrow('logger fora');
      const original = bus.published[0]?.message;
      expect(await accessUseCase().execute(event)).toMatchObject({ status: 'commanded', command: original });
      expect(bus.published[1]?.message).toEqual(original);
    });

    it('libera a reserva quando decide falha e permite retentativa', async () => {
      const decide = vi.fn()
        .mockRejectedValueOnce(new Error('banco fora'))
        .mockResolvedValue({ action: 'open', decidedAt: NOW });
      const useCase = new HandleAccessEventUseCase(
        { decide }, bus, clock, new SequentialIds(), seen, pending, silentLogger,
      );
      await expect(useCase.execute(event)).rejects.toThrow('banco fora');
      expect(await useCase.execute(event)).toMatchObject({ status: 'commanded' });
      expect(decide).toHaveBeenCalledTimes(2);
    });

    it('libera a reserva quando persistir o comando falha', async () => {
      const save = vi.spyOn(pending, 'save').mockRejectedValueOnce(new Error('falha ao salvar'));
      await expect(accessUseCase().execute(event)).rejects.toThrow('falha ao salvar');
      expect(await accessUseCase().execute(event)).toMatchObject({ status: 'commanded' });
      expect(save).toHaveBeenCalledTimes(2);
    });

    it.each([-5_001, 30_000, 60_000])('descarta replay/relógio futuro com idade %i sem decidir ou publicar', async (age) => {
      const decide = vi.fn();
      const useCase = new HandleAccessEventUseCase(
        { decide }, bus, clock, new SequentialIds(), seen, pending, silentLogger,
      );
      expect(await useCase.execute({ ...event, timestamp: new Date(NOW.getTime() - age).toISOString() }))
        .toEqual({ status: 'stale' });
      expect(decide).not.toHaveBeenCalled();
      expect(bus.published).toHaveLength(0);
    });

    it('publica o comando decidido, com expiracao de 10 s, e o deixa pendente', async () => {
      const result = await accessUseCase('open').execute(event);

      expect(result.status).toBe('commanded');
      expect(bus.published).toHaveLength(1);
      expect(bus.published[0]).toMatchObject({
        channel: 'commands',
        message: {
          terminalId: TERMINAL,
          action: 'open',
          reason: 'teste',
          timestamp: '2026-10-19T19:30:00.000Z',
          expiresAt: '2026-10-19T19:30:10.000Z',
        },
      });
      expect(pending.size).toBe(1);
    });

    it('propaga a decisao deny', async () => {
      await accessUseCase('deny').execute(event);

      expect(bus.published[0]?.message).toMatchObject({ action: 'deny' });
    });

    it('se a publicacao falhar, preserva o comando para retransmitir com o mesmo id', async () => {
      const failing = new RecordingBus();
      failing.publish = () => Promise.reject(new Error('broker fora'));
      const useCase = new HandleAccessEventUseCase(
        new FixedDecider('open'),
        failing,
        clock,
        new SequentialIds(),
        seen,
        pending,
        silentLogger,
      );

      await expect(useCase.execute(event)).rejects.toThrow('broker fora');

      expect(pending.size).toBe(1);
      expect(await accessUseCase().execute(event)).toMatchObject({ status: 'commanded' });
    });

    it('descarta a tentativa repetida (mesmo messageId) sem novo comando', async () => {
      const useCase = accessUseCase();
      await useCase.execute(event);

      const second = await useCase.execute(event);

      expect(second).toEqual({ status: 'duplicate' });
      expect(bus.published).toHaveLength(1);
    });
  });

  describe('HandleAckUseCase', () => {
    const ackFor = (commandId: string, messageId = UUID_B): AckMessage => ({
      ...envelope(messageId),
      commandId,
      status: 'executed',
    });

    it('correlaciona o ack ao comando pelo commandId', async () => {
      const output = await accessUseCase().execute(event);
      if (output.status !== 'commanded') throw new Error('esperava comando');

      const result = await new HandleAckUseCase(pending, seen, silentLogger).execute(
        ackFor(output.command.commandId),
      );

      expect(result).toEqual({ status: 'correlated', command: output.command });
      expect(pending.size).toBe(0);
    });

    it('nao correlaciona ack vindo de outro terminal', async () => {
      const output = await accessUseCase().execute(event);
      if (output.status !== 'commanded') throw new Error('esperava comando');

      const result = await new HandleAckUseCase(pending, seen, silentLogger).execute({
        ...ackFor(output.command.commandId),
        terminalId: 'terminal-02',
      });

      expect(result).toEqual({ status: 'unknown' });
      expect(pending.size).toBe(1);
    });

    it('ignora ack de comando desconhecido', async () => {
      const result = await new HandleAckUseCase(pending, seen, silentLogger).execute(
        ackFor('c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c99'),
      );

      expect(result).toEqual({ status: 'unknown' });
    });

    it('descarta ack repetido (mesmo messageId)', async () => {
      const useCase = new HandleAckUseCase(pending, seen, silentLogger);
      const ack = ackFor('c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c99');
      await useCase.execute(ack);

      expect(await useCase.execute(ack)).toEqual({ status: 'duplicate' });
    });
  });

  describe('PublishQrCodeUseCase', () => {
    it('publica QR v1 assinado com timestamps e TTL identicos aos claims', async () => {
      const ids = new SequentialIds();
      const signer = new HmacQrTokenSigner('a'.repeat(64));
      const validateCredential = new ValidateQrCredentialUseCase(clock, signer);
      const message = await new PublishQrCodeUseCase(
        bus,
        ids,
        new IssueQrCredentialUseCase(clock, ids, signer),
      ).execute({
        terminalId: TERMINAL,
      });

      expect(bus.published).toEqual([{ channel: 'qr', message }]);
      expect(message).toMatchObject({
        v: 1,
        terminalId: TERMINAL,
        timestamp: '2026-10-19T19:30:00.000Z',
        expiresAt: '2026-10-19T19:30:10.000Z',
      });
      expect(message.token).toMatch(/^v1\.[a-z0-9-]+\.[0-9]+\.[0-9]+\.[A-Za-z0-9_-]{43}$/);
      const validation = validateCredential.execute(message.token, message.terminalId);
      expect(validation.valid).toBe(true);
      if (!validation.valid) throw new Error('credencial assinada deveria ser valida');
      expect(new Date(validation.claims.issuedAt).toISOString()).toBe(message.timestamp);
      expect(new Date(validation.claims.expiresAt).toISOString()).toBe(message.expiresAt);
      expect(validation.claims.expiresAt - validation.claims.issuedAt).toBe(QR_TTL_MS);
      expect(Buffer.byteLength(message.token, 'utf8')).toBeLessThanOrEqual(152);
      expect(parsePayload('qr', TERMINAL, JSON.stringify(message))).toMatchObject({ ok: true });
    });
  });

  describe('QR credential crypto', () => {
    const signer = new HmacQrTokenSigner('a'.repeat(64));
    const issue = () => new IssueQrCredentialUseCase(clock, new SequentialIds(), signer);
    const validate = () => new ValidateQrCredentialUseCase(clock, signer);

    it('valida token assinado e emite apenas os claims necessarios', () => {
      const credential = issue().execute(TERMINAL);
      expect(validate().execute(credential.token, TERMINAL)).toMatchObject({ valid: true });
      const [version, terminal, issuedAt, expiresAt] = credential.token.split('.');
      expect({ version, terminal }).toEqual({ version: 'v1', terminal: TERMINAL });
      expect(Number(expiresAt) - Number(issuedAt)).toBe(QR_TTL_MS / 1000);
    });

    it('cabe no QR do terminal (152 bytes) com o maior terminal permitido', () => {
      const longTerminal = 'a'.repeat(64);
      const credential = issue().execute(longTerminal);

      expect(Buffer.byteLength(credential.token, 'utf8')).toBeLessThanOrEqual(152);
      expect(validate().execute(credential.token, longTerminal).valid).toBe(true);
    });

    it('rejeita assinatura adulterada', () => {
      const { token } = issue().execute(TERMINAL);
      const [payload, signature] = token.split('.');
      const altered = `${payload}.${signature![0] === 'A' ? 'B' : 'A'}${signature!.slice(1)}`;
      expect(validate().execute(altered, TERMINAL)).toEqual({ valid: false, reason: 'invalid' });
    });

    it('rejeita formato invalido', () => {
      expect(validate().execute('not.a.valid.token', TERMINAL)).toEqual({ valid: false, reason: 'invalid' });
    });

    it('rejeita terminal divergente', () => {
      const { token } = issue().execute(TERMINAL);
      expect(validate().execute(token, 'terminal-02')).toEqual({ valid: false, reason: 'invalid' });
    });

    it('aceita no instante emitido e rejeita no limite expiresAt', () => {
      const { token, expiresAt } = issue().execute(TERMINAL);
      expect(validate().execute(token, TERMINAL).valid).toBe(true);
      clock.date = new Date(expiresAt);
      expect(validate().execute(token, TERMINAL)).toEqual({ valid: false, reason: 'expired' });
    });

    it('rejeita token ainda nao emitido', () => {
      const signerNow = new HmacQrTokenSigner('a'.repeat(64));
      const issued = Math.floor(NOW.getTime() / 1000) + 1;
      const payload = `v1.${TERMINAL}.${issued}.${issued + QR_TTL_MS / 1000}`;
      const token = `${payload}.${signerNow.sign(payload)}`;
      expect(validate().execute(token, TERMINAL)).toEqual({ valid: false, reason: 'invalid' });
    });
  });
});
