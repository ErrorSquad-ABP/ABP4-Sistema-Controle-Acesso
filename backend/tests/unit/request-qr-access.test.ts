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
import type { AckMessage, CommandMessage } from '../../src/domain/terminal/messages.js';
import { HmacQrTokenSigner } from '../../src/infrastructure/ids/hmac-qr-token-signer.js';
import { DispatchPendingCommandsUseCase } from '../../src/application/terminal/dispatch-pending-commands.use-case.js';
import { FixedClock, NOW, RecordingBus, SequentialIds, silentLogger } from '../support/terminal-fakes.js';

const TERMINAL = 'terminal-01';
const USER = '2b0f2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const REQUEST_ID = '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const signer = new HmacQrTokenSigner('a'.repeat(64));

class MapCommandStore implements CommandStore {
  constructor(
    readonly byRequest = new Map<string, CommandMessage>(),
    readonly byId = new Map<string, CommandMessage>(),
    readonly acked = new Map<string, string>(),
    readonly published = new Set<string>(),
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

  async markPublished(commandId: string) {
    this.published.add(commandId);
  }

  async listUndispatched(now: Date, decidedBefore: Date, limit: number) {
    return [...this.byRequest.values()]
      .filter((command) =>
        !this.published.has(command.commandId) &&
        !this.acked.has(command.commandId) &&
        Date.parse(command.expiresAt) > now.getTime() &&
        Date.parse(command.timestamp) <= decidedBefore.getTime())
      .slice(0, limit);
  }

  async purgeExpired(): Promise<number> {
    return 0;
  }

  clone(): MapCommandStore {
    return new MapCommandStore(
      new Map(this.byRequest), new Map(this.byId), new Map(this.acked), new Set(this.published),
    );
  }

  restore(other: MapCommandStore): void {
    this.byRequest.clear();
    for (const [key, value] of other.byRequest) this.byRequest.set(key, value);
    this.byId.clear();
    for (const [key, value] of other.byId) this.byId.set(key, value);
    this.acked.clear();
    for (const [key, value] of other.acked) this.acked.set(key, value);
    this.published.clear();
    for (const id of other.published) this.published.add(id);
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

function setup() {
  const clock = new FixedClock(NOW);
  const ids = new SequentialIds();
  const repository = new InMemoryAccessRepository();
  const qr = new ValidateQrCredentialUseCase(clock, signer);
  const bus = new RecordingBus();
  const publish = new PublishCommandUseCase(repository.store, bus, clock, ids);
  const useCase = new RequestQrAccessUseCase(
    new DecideAccessUseCase(repository, clock, qr, ids),
    publish,
    ids,
    repository,
    silentLogger,
  );
  // Um relay novo por chamada simula o worker reiniciado sobre o mesmo banco.
  const relay = () =>
    new DispatchPendingCommandsUseCase(
      repository.store,
      repository,
      new PublishCommandUseCase(repository.store, bus, clock, ids),
      clock,
      silentLogger,
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
});
