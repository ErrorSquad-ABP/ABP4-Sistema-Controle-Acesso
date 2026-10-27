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
import { FixedClock, NOW, RecordingBus, SequentialIds } from '../support/terminal-fakes.js';

const TERMINAL = 'terminal-01';
const USER = '2b0f2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const REQUEST_ID = '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
const signer = new HmacQrTokenSigner('a'.repeat(64));

class MapCommandStore implements CommandStore {
  constructor(
    readonly byRequest = new Map<string, CommandMessage>(),
    readonly byId = new Map<string, CommandMessage>(),
    readonly acked = new Map<string, string>(),
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

  clone(): MapCommandStore {
    return new MapCommandStore(new Map(this.byRequest), new Map(this.byId), new Map(this.acked));
  }

  restore(other: MapCommandStore): void {
    this.byRequest.clear();
    for (const [key, value] of other.byRequest) this.byRequest.set(key, value);
    this.byId.clear();
    for (const [key, value] of other.byId) this.byId.set(key, value);
    this.acked.clear();
    for (const [key, value] of other.acked) this.acked.set(key, value);
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
  const useCase = new RequestQrAccessUseCase(
    new DecideAccessUseCase(repository, clock, qr, ids),
    new PublishCommandUseCase(repository.store, bus, clock, ids),
    ids,
    repository,
  );
  const token = new IssueQrCredentialUseCase(clock, ids, signer).execute(TERMINAL).token;
  const request = {
    requestId: REQUEST_ID,
    userId: USER,
    terminalId: TERMINAL,
    qrToken: token,
    position: { latitude: -23, longitude: -45 },
  };
  return { useCase, repository, bus, request };
}

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
    const publish = bus.publish.bind(bus);
    bus.publish = () => Promise.reject(new Error('broker fora'));

    await expect(useCase.execute(request)).rejects.toThrow('broker fora');
    const persisted = repository.store.byRequest.get(REQUEST_ID);
    bus.publish = publish;

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
