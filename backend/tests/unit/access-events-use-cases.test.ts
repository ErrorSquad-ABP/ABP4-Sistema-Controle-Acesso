import { describe, expect, it } from 'vitest';
import { ListAccessEventsUseCase } from '../../src/application/access-events/list-access-events.use-case.js';
import { ListMyAccessEventsUseCase } from '../../src/application/access-events/list-my-access-events.use-case.js';
import type { AccessEventView } from '../../src/domain/ports/access-event-repository.js';
import { InMemoryAccessEventRepository } from '../support/in-memory-access-events.js';

const events: AccessEventView[] = [
  {
    id: 'b0000000-0000-4000-8000-000000000001',
    occurredAt: '2026-10-20T12:00:00.000Z',
    terminalId: 'terminal-01',
    method: 'QR',
    decision: 'GRANTED',
    reason: null,
    user: { id: 'u1', name: 'Ana', role: 'RESIDENT' },
    location: { id: 'l1', name: 'Recepcao' },
    authorizationId: null,
    distanceMeters: 12.5,
  },
  {
    id: 'b0000000-0000-4000-8000-000000000002',
    occurredAt: '2026-10-19T12:00:00.000Z',
    terminalId: 'terminal-01',
    method: 'NFC',
    decision: 'DENIED',
    reason: 'NO_AUTHORIZATION',
    user: { id: 'u2', name: 'Bia', role: 'VISITOR' },
    location: { id: 'l1', name: 'Recepcao' },
    authorizationId: null,
    distanceMeters: null,
  },
];

describe('historico de acessos', () => {
  it('minha lista força o userId do token', async () => {
    const repo = new InMemoryAccessEventRepository(events);

    const out = await new ListMyAccessEventsUseCase(repo).execute('u1', { page: 1, pageSize: 20 });

    expect(out.items).toHaveLength(1);
    expect(out.items[0]?.user?.id).toBe('u1');
    expect(out.total).toBe(1);
  });

  it('filtra por decisao e periodo inclusivo', async () => {
    const repo = new InMemoryAccessEventRepository(events);

    const out = await new ListAccessEventsUseCase(repo).execute({
      page: 1,
      pageSize: 20,
      decision: 'DENIED',
      from: '2026-10-19T00:00:00Z',
      to: '2026-10-19T23:59:59Z',
    });

    expect(out.items.map((event) => event.id)).toEqual(['b0000000-0000-4000-8000-000000000002']);
  });

  it('pagina e devolve o total do filtro', async () => {
    const repo = new InMemoryAccessEventRepository(events);

    const out = await new ListAccessEventsUseCase(repo).execute({ page: 2, pageSize: 1 });

    expect(out.total).toBe(2);
    expect(out.items).toHaveLength(1);
    expect(out.items[0]?.id).toBe('b0000000-0000-4000-8000-000000000002');
  });

  it('combina filtros de metodo e local', async () => {
    const repo = new InMemoryAccessEventRepository(events);

    const out = await new ListAccessEventsUseCase(repo).execute({
      page: 1,
      pageSize: 20,
      method: 'NFC',
      locationId: 'l1',
    });

    expect(out.items).toHaveLength(1);
    expect(out.items[0]?.method).toBe('NFC');
  });
});
