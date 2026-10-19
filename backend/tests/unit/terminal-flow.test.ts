import { describe, expect, it } from 'vitest';
import { HandleAccessEventUseCase } from '../../src/application/terminal/handle-access-event.use-case.js';
import { HandleAckUseCase } from '../../src/application/terminal/handle-ack.use-case.js';
import type { CommandMessage } from '../../src/domain/terminal/messages.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { SeenMessages } from '../../src/domain/terminal/seen-messages.js';
import { topicFor } from '../../src/domain/terminal/topics.js';
import { AlwaysOpenAccessDecider } from '../../src/infrastructure/terminal/always-open-access-decider.js';
import { TerminalMessageRouter } from '../../src/main/mqtt/terminal-message-router.js';
import { SimulatedTerminal } from '../../src/main/sim/simulated-terminal.js';
import {
  FixedClock,
  NOW,
  RecordingBus,
  SequentialIds,
  TERMINAL,
  UUID_CMD,
  envelope,
  silentLogger,
} from '../support/terminal-fakes.js';

/** Liga consumidor (router + use cases) e simulador por barramentos em memoria. */
function setup() {
  const clock = new FixedClock(NOW);
  const consumerBus = new RecordingBus();
  const terminalBus = new RecordingBus();
  const pending = new PendingCommands();
  const seen = new SeenMessages();
  const presence: [string, boolean][] = [];

  const router = new TerminalMessageRouter(
    new HandleAccessEventUseCase(
      new AlwaysOpenAccessDecider(),
      consumerBus,
      clock,
      new SequentialIds(),
      seen,
      pending,
      silentLogger,
    ),
    new HandleAckUseCase(pending, seen, silentLogger),
    silentLogger,
    (terminalId, online) => presence.push([terminalId, online]),
  );
  const terminal = new SimulatedTerminal(TERMINAL, terminalBus, clock, new SequentialIds(), silentLogger);
  return { clock, consumerBus, terminalBus, terminal, router, presence, pending };
}

const asPayload = (message: unknown) => JSON.stringify(message);

describe('fluxo consumidor <-> simulador', () => {
  it('tentativa NFC gera comando e o ack volta correlacionado', async () => {
    const { consumerBus, terminalBus, terminal, router, pending } = setup();

    await terminal.readNfc('04A1B2C3');
    const attempt = terminalBus.published[0];
    await router.route(topicFor('access-events', TERMINAL), asPayload(attempt?.message));

    const command = consumerBus.published[0]?.message as CommandMessage;
    expect(consumerBus.published[0]?.channel).toBe('commands');
    expect(command.action).toBe('open');

    const ack = await terminal.onMessage(topicFor('commands', TERMINAL), asPayload(command));
    expect(ack).toMatchObject({ commandId: command.commandId, status: 'executed' });

    await router.route(topicFor('acks', TERMINAL), asPayload(ack));
    expect(pending.size).toBe(0);
  });

  it('simulador responde ack "expired" a comando vencido, sem executar', async () => {
    const { terminal, terminalBus } = setup();
    const vencido = {
      ...envelope(),
      commandId: UUID_CMD,
      expiresAt: '2026-10-19T19:29:59.000Z',
      action: 'open',
    };

    const ack = await terminal.onMessage(topicFor('commands', TERMINAL), asPayload(vencido));

    expect(ack).toMatchObject({ commandId: UUID_CMD, status: 'expired' });
    expect(terminalBus.published).toHaveLength(1);
  });

  it('simulador nao executa duas vezes o mesmo commandId (reenvia o ack anterior)', async () => {
    const { terminal } = setup();
    const comando = { ...envelope(), commandId: UUID_CMD, expiresAt: '2026-10-19T19:30:10.000Z', action: 'open' };

    const first = await terminal.onMessage(topicFor('commands', TERMINAL), asPayload(comando));
    const second = await terminal.onMessage(topicFor('commands', TERMINAL), asPayload(comando));

    expect(second).toBe(first);
  });

  it('simulador ignora mensagens de outro terminal e canais que nao sao dele', async () => {
    const { terminal, terminalBus } = setup();

    expect(await terminal.onMessage('terminals/terminal-02/commands', '{}')).toBeUndefined();
    expect(await terminal.onMessage(topicFor('acks', TERMINAL), '{}')).toBeUndefined();
    expect(await terminal.onMessage(topicFor('commands', TERMINAL), 'lixo')).toBeUndefined();
    expect(terminalBus.published).toHaveLength(0);
  });

  it('router descarta payload invalido e topico desconhecido sem lancar', async () => {
    const { router, consumerBus } = setup();

    await router.route(topicFor('access-events', TERMINAL), 'nao e json');
    await router.route('outro/topico', '{}');
    await router.route(topicFor('qr', TERMINAL), '{}');

    expect(consumerBus.published).toHaveLength(0);
  });

  it('router informa presenca pelo status e pelas tentativas', async () => {
    const { router, presence, terminal, terminalBus } = setup();

    await terminal.announce('online');
    await router.route(topicFor('status', TERMINAL), asPayload(terminalBus.published[0]?.message));
    await terminal.announce('offline');
    await router.route(topicFor('status', TERMINAL), asPayload(terminalBus.published[1]?.message));

    expect(presence).toEqual([
      [TERMINAL, true],
      [TERMINAL, false],
    ]);
  });
});
