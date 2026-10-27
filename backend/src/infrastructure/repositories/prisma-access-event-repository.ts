import type {
  AccessEventFilters,
  AccessEventRepository,
  AccessEventView,
} from '../../domain/ports/access-event-repository.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

const SELECT = {
  id: true,
  occurredAt: true,
  method: true,
  decision: true,
  reason: true,
  authorizationId: true,
  distanceMeters: true,
  user: { select: { id: true, name: true, role: true } },
  location: { select: { id: true, name: true } },
} as const;

type Row = Prisma.AccessEventGetPayload<{ select: typeof SELECT }>;

function toView(row: Row): AccessEventView {
  // O contrato exige location; o filtro `locationId: { not: null }` garante a relacao.
  if (!row.location) throw new Error('evento sem local nao deveria chegar ao contrato');
  return {
    id: row.id,
    occurredAt: row.occurredAt.toISOString(),
    method: row.method,
    decision: row.decision,
    reason: row.reason,
    user: row.user,
    location: row.location,
    authorizationId: row.authorizationId,
    distanceMeters: row.distanceMeters === null ? null : Number(row.distanceMeters),
  };
}

export class PrismaAccessEventRepository implements AccessEventRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async list(filters: AccessEventFilters): Promise<{ items: AccessEventView[]; total: number }> {
    const where: Prisma.AccessEventWhereInput = { locationId: { not: null } };
    if (filters.userId) where.userId = filters.userId;
    if (filters.locationId) where.locationId = filters.locationId;
    if (filters.method) where.method = filters.method;
    if (filters.decision) where.decision = filters.decision;
    if (filters.from || filters.to) {
      where.occurredAt = {
        ...(filters.from ? { gte: filters.from } : {}),
        ...(filters.to ? { lte: filters.to } : {}),
      };
    }

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.accessEvent.findMany({
        where,
        orderBy: [{ occurredAt: 'desc' }, { id: 'desc' }],
        skip: (filters.page - 1) * filters.pageSize,
        take: filters.pageSize,
        select: SELECT,
      }),
      this.prisma.accessEvent.count({ where }),
    ]);

    return { items: rows.map(toView), total };
  }
}
