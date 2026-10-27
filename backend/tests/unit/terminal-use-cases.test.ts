import { beforeEach, describe, expect, it } from 'vitest';
import { HandleAccessEventUseCase } from '../../src/application/terminal/handle-access-event.use-case.js';
import { HandleAckUseCase } from '../../src/application/terminal/handle-ack.use-case.js';
import { PublishQrCodeUseCase } from '../../src/application/terminal/publish-qr-code.use-case.js';
import type { AccessDecider } from '../../src/domain/ports/access-decider.js';
import type { AccessEventMessage, AckMessage } from '../../src/domain/terminal/messages.js';
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
    return Promise.resolve({ action: this.action, reason: 'teste' });
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
    it('publica o qr com validade de 10 s', async () => {
      await new PublishQrCodeUseCase(bus, clock, new SequentialIds()).execute({
        terminalId: TERMINAL,
      });

      expect(bus.published[0]).toMatchObject({
        channel: 'qr',
        message: {
          terminalId: TERMINAL,
          token: 'tokentest123',
          timestamp: '2026-10-19T19:30:00.000Z',
          expiresAt: '2026-10-19T19:30:10.000Z',
        },
      });
    });
  });
});
