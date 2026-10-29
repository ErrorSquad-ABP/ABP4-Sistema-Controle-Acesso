import { describe, expect, it } from 'vitest';
import { DecideAccessUseCase } from '../../src/application/access/decide-access.use-case.js';
import { RequestQrAccessUseCase } from '../../src/application/access/request-qr-access.use-case.js';
import {
  IssueQrCredentialUseCase,
  ValidateQrCredentialUseCase,
} from '../../src/application/terminal/qr-credential.use-cases.js';
import { PublishCommandUseCase } from '../../src/application/terminal/publish-command.use-case.js';
import { ServiceUnavailableError } from '../../src/domain/errors/domain-error.js';
import type { AccessRecord, AccessRepository } from '../../src/domain/ports/access-repository.js';
import type { AckResult, CommandStore } from '../../src/domain/ports/command-store.js';
import type {
  AckMessage,
  Channel,
  CommandMessage,
  MessagesByChannel,
} from '../../src/domain/terminal/messages.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { DispatchPendingCommandsUseCase } from '../../src/application/terminal/dispatch-pending-commands.use-case.js';
import { FixedClock, NOW, RecordingBus, SequentialIds, silentLogger } from '../support/terminal-fakes.js';

const TERMINAL = 'terminal-01';
const USER = '2b0f2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const REQUEST_ID = '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const OTHER_REQUEST_ID = '4f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c11';
const signer = new HmacQrTokenSigner('a'.repeat(64));

class MapCommandStore implements CommandStore {
  constructor(
    readonly byRequest = new Map<string, CommandMessage>(),
    readonly byId = new Map<string, CommandMessage>(),
    readonly acked = new Map<string, string>(),
    /** Instante da reserva/ultima tentativa, como a coluna `publishedAt` no Postgres. */
    readonly publishedAt = new Map<string, number>(),
  ) {}

  async findByRequestId(requestId: string) {
    return this.byRequest.get(requestId);
  }

  async save(command: CommandMessage, requestId: string) {
    const previous = this.byRequest.get(requestId);
    if (previous) return previous;
    this.byRequest.set(requestId, command);
    this.byId.set(command.commandId, command);
    return command;
  }

  async acknowledge(ack: AckMessage): Promise<AckResult> {
    if (this.acked.has(ack.commandId)) return { status: 'duplicate' };
    const command = this.byId.get(ack.commandId);
    if (!command || command.terminalId !== ack.terminalId) return { status: 'unknown' };
    this.byId.delete(ack.commandId);
    this.acked.set(ack.commandId, 'ack');
    return { status: 'correlated', command };
  }

  async markPublished(commandId: string, at: Date) {
    this.publishedAt.set(commandId, at.getTime());
  }

  /** Mesmo contrato do Postgres: reserva antes de publicar; outra replica nao ve. */
  async claimUndispatched(now: Date, decidedBefore: Date, limit: number, staleBefore: Date) {
    const claimed = [...this.byRequest.values()]
      .filter((command) =>
        (this.publishedAt.get(command.commandId) ?? -Infinity) < staleBefore.getTime() &&
        !this.acked.has(command.commandId) &&
        Date.parse(command.expiresAt) > now.getTime() &&
        Date.parse(command.timestamp) <= decidedBefore.getTime())
      .sort((a, b) => Date.parse(a.expiresAt) - Date.parse(b.expiresAt))
      .slice(0, limit);
    for (const command of claimed) this.publishedAt.set(command.commandId, now.getTime());
    return claimed;
  }

  async releaseClaim(commandId: string) {
    this.publishedAt.delete(commandId);
  }

  async purgeExpired(): Promise<number> {
    return 0;
  }

  clone(): MapCommandStore {
    return new MapCommandStore(
      new Map(this.byRequest), new Map(this.byId), new Map(this.acked), new Map(this.publishedAt),
    );
  }

  restore(other: MapCommandStore): void {
    this.byRequest.clear();
    for (const [key, value] of other.byRequest) this.byRequest.set(key, value);
    this.byId.clear();
    for (const [key, value] of other.byId) this.byId.set(key, value);
    this.acked.clear();
    for (const [key, value] of other.acked) this.acked.set(key, value);
    this.publishedAt.clear();
    for (const [key, value] of other.publishedAt) this.publishedAt.set(key, value);
  }
}

class AccessRepositoryTx {
  constructor(
    readonly events: Map<string, AccessRecord>,
    readonly store: MapCommandStore,
    private readonly consume: () => void,
  ) {}

  async findEvent(id: string) {
    return this.events.get(id) ?? null;
  }

  async findTerminal(id: string) {
    if (id !== TERMINAL) return null;
    return {
      id: TERMINAL,
      active: true,
      location: { id: 'local-01', name: 'Recepcao', active: true, latitude: -23, longitude: -45, radiusMeters: 100 },
    };
  }

  async findUser(id: string) {
    return { id, name: 'Maria', role: 'RESIDENT' as const, active: true };
  }

  async findCredential() {
    return null;
  }

  async findAuthorizations(userId: string, locationId: string) {
    return [{
      id: 'autorizacao', userId, locationId,
      startsAt: new Date(NOW.getTime() - 60_000), endsAt: new Date(NOW.getTime() + 60_000),
      maxUses: 5, usedCount: 0, canceledAt: null,
    }];
  }

  async consumeAuthorization() {
    this.consume();
    return true;
  }

  async record(event: AccessRecord) {
    this.events.set(event.id, event);
    return event;
  }

  async saveCommand(command: CommandMessage, requestId: string) {
    return this.store.save(command, requestId);
  }
}

/** Transacao em memoria com o mesmo contrato do Postgres: commita so no fim. */
class InMemoryAccessRepository implements AccessRepository {
  readonly events = new Map<string, AccessRecord>();
  readonly store = new MapCommandStore();
  dispatchable = true;
  private consumed = 0;

  async ready(): Promise<void> {}

  async canDispatch(): Promise<boolean> {
    return this.dispatchable;
  }

  async transaction<T>(_requestId: string, work: (tx: AccessRepositoryTx) => Promise<T>): Promise<T> {
    const draft = new AccessRepositoryTx(
      new Map(this.events),
      this.store.clone(),
      () => { this.consumed += 1; },
    );
    const result = await work(draft);
    this.events.clear();
    for (const [id, event] of draft.events) this.events.set(id, event);
    this.store.restore(draft.store);
    return result;
  }

  consumeCount(): number {
    return this.consumed;
  }
}

function setup(clock = new FixedClock(NOW), bus = new RecordingBus()) {
  const ids = new SequentialIds();
  const repository = new InMemoryAccessRepository();
  const qr = new ValidateQrCredentialUseCase(clock, signer);
  const publish = new PublishCommandUseCase(repository.store, bus, clock, ids);
  const useCase = new RequestQrAccessUseCase(
    new DecideAccessUseCase(repository, clock, qr, ids),
    publish,
    ids,
    repository,
    silentLogger,
  );
  // Um relay novo por chamada simula o worker reiniciado sobre o mesmo banco.
  const relay = (withinWindow?: (now: Date) => boolean) =>
    new DispatchPendingCommandsUseCase(
      repository.store,
      repository,
      new PublishCommandUseCase(repository.store, bus, clock, ids),
      clock,
      silentLogger,
      withinWindow,
    );
  const token = new IssueQrCredentialUseCase(clock, ids, signer).execute(TERMINAL).token;
  const request = {
    requestId: REQUEST_ID,
    userId: USER,
    terminalId: TERMINAL,
    qrToken: token,
    position: { latitude: -23, longitude: -45 },
  };
  return { useCase, repository, bus, request, clock, relay };
}

function failTransport(bus: RecordingBus): () => void {
  const publish = bus.publish.bind(bus);
  bus.publish = () => Promise.reject(new Error('broker fora'));
  return () => {
    bus.publish = publish;
  };
}

const after = (clock: FixedClock, ms: number) => {
  clock.date = new Date(NOW.getTime() + ms);
};

const published = (bus: RecordingBus, index: number) => bus.published[index]?.message as CommandMessage;

/**
 * Broker lento: cada publish avanca o relogio como se a entrega levasse `delayMs`.
 * A janela do claim e medida no relogio, entao nao precisa de timer real.
 * `during[i]` roda no meio do publish `i`; e onde a replica concorrente entra.
 */
class SlowBus extends RecordingBus {
  readonly during: (() => Promise<void>)[] = [];
  private cursor = 0;

  constructor(private readonly clock: FixedClock, private readonly delayMs: number) {
    super();
  }

  override async publish<C extends Channel>(channel: C, message: MessagesByChannel[C]): Promise<void> {
    const index = this.cursor;
    this.cursor += 1;
    await super.publish(channel, message);
    this.clock.date = new Date(this.clock.date.getTime() + this.delayMs);
    await this.during[index]?.();
  }
}

describe('DT-02: pedido QR idempotente', () => {
  it('nao republica apos desativar o terminal, mesmo dentro da janela', async () => {
    const { useCase, repository, bus, request } = setup();

    await useCase.execute(request);
    repository.dispatchable = false;

    await expect(useCase.execute(request)).rejects.toBeInstanceOf(ServiceUnavailableError);
    expect(bus.published).toHaveLength(1);
  });

  it('repetir o mesmo requestId devolve o mesmo evento e o mesmo comando', async () => {
    const { useCase, repository, bus, request } = setup();

    const first = await useCase.execute(request);
    const second = await useCase.execute(request);

    expect(first.decision).toBe('GRANTED');
    expect(second.event.id).toBe(first.event.id);
    expect(second.event.id).toBe(REQUEST_ID);
    expect(repository.store.byRequest.size).toBe(1);
    expect(repository.consumeCount()).toBe(1);
    expect(bus.published).toHaveLength(2);
    expect(published(bus, 1).commandId).toBe(published(bus, 0).commandId);
    expect(published(bus, 1).expiresAt).toBe(published(bus, 0).expiresAt);
  });

  it('repetir apos falha de publicacao nao consome a autorizacao de novo', async () => {
    const { useCase, repository, bus, request } = setup();
    const restore = failTransport(bus);

    const first = await useCase.execute(request);
    expect(first).toMatchObject({ decision: 'GRANTED', commandPublished: false });
    const persisted = repository.store.byRequest.get(REQUEST_ID);
    restore();

    const retry = await useCase.execute(request);

    expect(retry.event.id).toBe(REQUEST_ID);
    expect(retry.commandPublished).toBe(true);
    expect(repository.consumeCount()).toBe(1);
    expect(bus.published).toHaveLength(1);
    expect(published(bus, 0).commandId).toBe(persisted?.commandId);
  });

  it('recusa o mesmo requestId para outro usuario', async () => {
    const { useCase, request } = setup();
    await useCase.execute(request);
    await expect(useCase.execute({ ...request, userId: 'outro-usuario' }))
      .rejects.toMatchObject({ code: 'CONFLICT' });
  });
});

describe('DT-13: relay recupera a publicacao QR apos falha de transporte', () => {
  it('entrega a intencao pendente sem novo consumo e com o mesmo commandId e prazo', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    const persisted = repository.store.byRequest.get(REQUEST_ID);

    // Broker ainda fora: o ciclo para e a intencao continua pendente.
    after(clock, 2_000);
    expect(await relay().execute()).toMatchObject({ published: 0, interrupted: true });

    restore();
    after(clock, 3_000);
    // Relay novo: mesmo resultado depois de reiniciar o worker.
    expect(await relay().execute()).toMatchObject({ published: 1, interrupted: false });

    expect(bus.published).toHaveLength(1);
    expect(published(bus, 0)).toEqual(persisted);
    expect(repository.consumeCount()).toBe(1);
    expect(await relay().execute()).toMatchObject({ published: 0 });
    expect(bus.published).toHaveLength(1);
  });

  it('nao republica o que ja foi entregue no pedido', async () => {
    const { useCase, bus, request, clock, relay } = setup();
    await useCase.execute(request);

    after(clock, 2_000);
    expect(await relay().execute()).toMatchObject({ published: 0 });
    expect(bus.published).toHaveLength(1);
  });

  it('espera a folga antes de disputar com a publicacao em curso', async () => {
    const { useCase, bus, request, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();

    expect(await relay().execute()).toMatchObject({ published: 0 });
    expect(bus.published).toHaveLength(0);
  });

  it('nunca publica abertura vencida', async () => {
    const { useCase, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();

    after(clock, 10_000);
    expect(await relay().execute()).toMatchObject({ published: 0 });
    expect(bus.published).toHaveLength(0);
  });

  it('nao publica para terminal ou local desativado', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();
    repository.dispatchable = false;

    after(clock, 2_000);
    expect(await relay().execute()).toMatchObject({ published: 0, skipped: 1 });
    expect(bus.published).toHaveLength(0);
  });

  it('devolve a reserva quando o transporte falha e nao deixa a intencao presa', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);

    after(clock, 2_000);
    expect(await relay().execute()).toMatchObject({ claimed: 1, published: 0, failed: 1, interrupted: true });
    restore();

    after(clock, 3_000);
    expect(await relay().execute()).toMatchObject({ claimed: 1, published: 1, failed: 0 });
    expect(bus.published).toHaveLength(1);
    expect(repository.consumeCount()).toBe(1);
  });

  it('duas replicas do relay publicam o comando uma unica vez', async () => {
    const { useCase, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();

    after(clock, 2_000);
    const cycles = await Promise.all([relay().execute(), relay().execute()]);

    expect(cycles.reduce((total, cycle) => total + cycle.published, 0)).toBe(1);
    expect(bus.published).toHaveLength(1);
  });

  it('devolve a reserva e interrompe o ciclo quando o transporte falha no primeiro comando', async () => {
    const { useCase, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    await useCase.execute({ ...request, requestId: OTHER_REQUEST_ID });
    expect(bus.published).toHaveLength(0);

    after(clock, 2_000);
    // Claim por item: so o comando corrente estava reservado quando falhou.
    expect(await relay().execute())
      .toMatchObject({ claimed: 1, published: 0, failed: 1, interrupted: true });

    restore();
    after(clock, 3_000);
    expect(await relay().execute()).toMatchObject({ claimed: 2, published: 2, failed: 0 });
    const ids = bus.published.map((entry) => (entry.message as CommandMessage).commandId);
    expect(new Set(ids).size).toBe(2);

    expect(await relay().execute()).toMatchObject({ claimed: 0, published: 0 });
    expect(bus.published).toHaveLength(2);
  });

  it('devolve a reserva e interrompe o ciclo quando a checagem de terminal/local lanca', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    await useCase.execute({ ...request, requestId: OTHER_REQUEST_ID });
    restore();

    repository.canDispatch = () => Promise.reject(new Error('banco fora'));
    after(clock, 2_000);
    expect(await relay().execute())
      .toMatchObject({ claimed: 1, published: 0, failed: 1, interrupted: true });

    repository.canDispatch = async () => true;
    after(clock, 3_000);
    expect(await relay().execute()).toMatchObject({ claimed: 2, published: 2 });
    expect(bus.published).toHaveLength(2);
  });

  it('nao republica o comando enquanto o publish lento da outra replica ainda corre', async () => {
    const clock = new FixedClock(NOW);
    // 2,8 s por publish: o segundo comando da primeira replica fica em voo ate 5,6 s,
    // acima da janela de 5 s que libera uma reserva em lote.
    const bus = new SlowBus(clock, 2_800);
    const { useCase, request, relay } = setup(clock, bus);
    const restore = failTransport(bus);
    await useCase.execute(request);
    await useCase.execute({ ...request, requestId: OTHER_REQUEST_ID });
    restore();
    expect(bus.published).toHaveLength(0);

    after(clock, 2_000);
    let rivalPublished = -1;
    // A replica concorrente entra no meio do segundo publish, com a reserva antiga.
    bus.during[1] = async () => {
      rivalPublished = (await relay().execute()).published;
    };

    expect(await relay().execute())
      .toMatchObject({ claimed: 2, published: 2, failed: 0, interrupted: false });
    expect(rivalPublished).toBe(0);

    const ids = bus.published.map((entry) => (entry.message as CommandMessage).commandId);
    expect(ids).toHaveLength(2);
    expect(new Set(ids).size).toBe(2);
  });

  it('para de consultar quando a janela fecha no meio do ciclo', async () => {
    const { useCase, bus, request, relay, clock } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    await useCase.execute({ ...request, requestId: OTHER_REQUEST_ID });
    restore();
    after(clock, 2_000);

    // Duas intencoes pendentes, mas a janela so permite o primeiro claim.
    const janela = [true, false];
    const out = await relay(() => janela.shift() ?? false).execute();

    expect(out.claimed).toBe(1);
    expect(out.published).toBe(1);
  });

  it('reclama reserva orfa de 6 s, ainda dentro do prazo do comando', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();
    // Reserva de um processo que morreu entre marcar e publicar.
    expect(await repository.store.claimUndispatched(
      NOW, new Date(NOW.getTime() + 1_000), 10, new Date(NOW.getTime() - 60_000),
    )).toHaveLength(1);

    after(clock, 6_000);
    expect(await relay().execute()).toMatchObject({ claimed: 1, published: 1 });
    expect(bus.published).toHaveLength(1);
  });

  it('nao rouba a reserva de 2 s de um relay vivo', async () => {
    const { useCase, repository, bus, request, clock, relay } = setup();
    const restore = failTransport(bus);
    await useCase.execute(request);
    restore();
    after(clock, 4_000);
    expect(await repository.store.claimUndispatched(
      clock.now(), new Date(clock.now().getTime() + 1_000), 10,
      new Date(clock.now().getTime() - 60_000),
    )).toHaveLength(1);

    after(clock, 2_000);
    expect(await relay().execute()).toMatchObject({ claimed: 0, published: 0 });
    expect(bus.published).toHaveLength(0);
  });
});
