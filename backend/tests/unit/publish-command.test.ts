import { describe, expect, it } from 'vitest';
import { PublishCommandUseCase } from '../../src/application/terminal/publish-command.use-case.js';
import { HandleAckUseCase } from '../../src/application/terminal/handle-ack.use-case.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { SeenMessages } from '../../src/domain/terminal/seen-messages.js';
import { FixedClock, NOW, RecordingBus, SequentialIds, TERMINAL, UUID_A, envelope, silentLogger } from '../support/terminal-fakes.js';

describe('DT-02: envio e ACK pelo mesmo contrato de armazenamento', () => {
  it('registra antes de publicar e correlaciona o ACK de outra instancia', async () => {
    const store = new PendingCommands();
    const bus = new RecordingBus();
    bus.publish = async (_channel, command) => {
      expect(await store.findByRequestId(UUID_A)).toEqual(command);
    };
    const command = await new PublishCommandUseCase(store, bus, new FixedClock(NOW), new SequentialIds())
      .execute({ requestId: UUID_A, terminalId: TERMINAL, action: 'open', reason: 'authorized' });
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
    const input = { requestId: UUID_A, terminalId: TERMINAL, action: 'open' as const };
    await expect(useCase.execute(input)).rejects.toThrow('conexao perdida');
    const saved = await store.findByRequestId(UUID_A);
    bus.publish = publish;
    expect(await useCase.execute(input)).toEqual(saved);
    expect(bus.published).toHaveLength(1);
  });

  it('nao republica abertura cuja validade ja terminou', async () => {
    const clock = new FixedClock(NOW);
    const bus = new RecordingBus();
    const useCase = new PublishCommandUseCase(new PendingCommands(), bus, clock, new SequentialIds());
    const input = { requestId: UUID_A, terminalId: TERMINAL, action: 'open' as const };
    await useCase.execute(input);
    clock.date = new Date(NOW.getTime() + 10_000);
    await expect(useCase.execute(input)).rejects.toThrow('expirado');
    expect(bus.published).toHaveLength(1);
  });

  it('rejeita colisao de requestId entre terminais antes de publicar', async () => {
    const bus = new RecordingBus();
    const useCase = new PublishCommandUseCase(new PendingCommands(), bus, new FixedClock(NOW), new SequentialIds());
    await useCase.execute({ requestId: UUID_A, terminalId: TERMINAL, action: 'open' });
    await expect(useCase.execute({ requestId: UUID_A, terminalId: 'outro-terminal', action: 'open' })).rejects.toThrow('solicitacao');
    expect(bus.published).toHaveLength(1);
  });
});
