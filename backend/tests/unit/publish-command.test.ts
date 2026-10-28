import { describe, expect, it } from 'vitest';
import { PublishCommandUseCase } from '../../src/application/terminal/publish-command.use-case.js';
import { HandleAckUseCase } from '../../src/application/terminal/handle-ack.use-case.js';
import { COMMAND_TTL_MS } from '../../src/domain/terminal/messages.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { SeenMessages } from '../../src/domain/terminal/seen-messages.js';
import {
  FixedClock,
  NOW,
  RecordingBus,
  SequentialIds,
  TERMINAL,
  UUID_A,
  envelope,
  silentLogger,
} from '../support/terminal-fakes.js';

const input = { requestId: UUID_A, terminalId: TERMINAL, action: 'open' as const, decidedAt: NOW };

describe('DT-02: envio e ACK pelo mesmo contrato de armazenamento', () => {
  it('registra antes de publicar e correlaciona o ACK de outra instancia', async () => {
    const store = new PendingCommands();
    const bus = new RecordingBus();
    bus.publish = async (_channel, command) => {
      expect(await store.findByRequestId(UUID_A)).toEqual(command);
    };
    const { command } = await new PublishCommandUseCase(
      store,
      bus,
      new FixedClock(NOW),
      new SequentialIds(),
    ).execute({ ...input, reason: 'authorized' });

    const ackHandler = new HandleAckUseCase(store, new SeenMessages(), silentLogger);
    expect(await ackHandler.execute({ ...envelope(), commandId: command.commandId, status: 'executed' }))
      .toMatchObject({ status: 'correlated', command });
  });

  it('preserva commandId e expiracao ao repetir uma solicitacao apos falha de publicacao', async () => {
    const store = new PendingCommands();
    const bus = new RecordingBus();
    const publish = bus.publish.bind(bus);
    bus.publish = () => Promise.reject(new Error('conexao perdida'));
    const useCase = new PublishCommandUseCase(store, bus, new FixedClock(NOW), new SequentialIds());

    await expect(useCase.execute(input)).rejects.toThrow('conexao perdida');
    const saved = await store.findByRequestId(UUID_A);
    bus.publish = publish;

    const retry = await useCase.execute(input);
    expect(retry.command).toEqual(saved);
    expect(bus.published).toHaveLength(1);
  });

  it('DT-13: so tira da outbox depois da entrega ao broker', async () => {
    const store = new PendingCommands();
    const bus = new RecordingBus();
    const publish = bus.publish.bind(bus);
    bus.publish = () => Promise.reject(new Error('conexao perdida'));
    const useCase = new PublishCommandUseCase(store, bus, new FixedClock(NOW), new SequentialIds());
    const pending = () => store.listUndispatched(NOW, NOW, 10);

    await expect(useCase.execute(input)).rejects.toThrow('conexao perdida');
    expect(await pending()).toHaveLength(1);

    bus.publish = publish;
    await useCase.execute(input);
    expect(await pending()).toHaveLength(0);
  });

  it('retentativa depois da janela nao publica abertura nem cria prazo novo', async () => {
    const store = new PendingCommands();
    const bus = new RecordingBus();
    const clock = new FixedClock(NOW);
    const useCase = new PublishCommandUseCase(store, bus, clock, new SequentialIds());
    const decisionCommand = { ...input };

    const first = await useCase.execute(decisionCommand);
    expect(first.published).toBe(true);

    // Decisao de 11 s atras: a janela do comando ja passou.
    clock.date = new Date(NOW.getTime() + 11_000);
    const late = await useCase.execute(decisionCommand);

    expect(late.published).toBe(false);
    expect(late.command.commandId).toBe(first.command.commandId);
    expect(late.command.expiresAt).toBe(first.command.expiresAt);
    expect(bus.published).toHaveLength(1);
  });

  it('nao abre quando a intencao persistida falta e a decisao ja venceu', async () => {
    // Simula a falha entre a decisao e a publicacao: sem registro, o prazo ainda
    // nasce do instante da decisao, entao a retentativa tardia nao abre.
    const bus = new RecordingBus();
    const clock = new FixedClock(new Date(NOW.getTime() + 11_000));
    const useCase = new PublishCommandUseCase(new PendingCommands(), bus, clock, new SequentialIds());

    const late = await useCase.execute(input);

    expect(late.published).toBe(false);
    expect(bus.published).toHaveLength(0);
    expect(late.command.expiresAt).toBe(new Date(NOW.getTime() + COMMAND_TTL_MS).toISOString());
  });

  it('nao abre com comando de outra tentativa, mesmo com o mesmo requestId', async () => {
    const bus = new RecordingBus();
    const useCase = new PublishCommandUseCase(new PendingCommands(), bus, new FixedClock(NOW), new SequentialIds());
    await useCase.execute(input);

    await expect(useCase.execute({ ...input, terminalId: 'outro-terminal' })).rejects.toThrow('solicitacao');
    expect(bus.published).toHaveLength(1);
  });
});
