import {
  toAuthorizationView,
  type AuthorizationRecord,
  type AuthorizationView,
} from '../../domain/authorizations/authorization.js';
import type {
  AuthorizationForUserFilters,
  AuthorizationRepository,
} from '../../domain/ports/authorization-repository.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

const SELECT = {
  id: true,
  startsAt: true,
  endsAt: true,
  maxUses: true,
  usedCount: true,
  canceledAt: true,
  cancelReason: true,
  createdAt: true,
  user: { select: { id: true, name: true, role: true } },
  location: { select: { id: true, name: true } },
} as const;

type Row = Prisma.AuthorizationGetPayload<{ select: typeof SELECT }>;

// Row tem o mesmo shape de AuthorizationRecord (datas continuam Date).
const toRecord = (row: Row): AuthorizationRecord => row;

export class PrismaAuthorizationRepository implements AuthorizationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  /** Traduz o status calculado para o mesmo `where` do banco (paginacao real). */
  private statusWhere(status: NonNullable<AuthorizationForUserFilters['status']>, now: Date): Prisma.AuthorizationWhereInput {
    const maxUses = this.prisma.authorization.fields.maxUses;
    switch (status) {
      case 'CANCELED':
        return { canceledAt: { not: null } };
      case 'SCHEDULED':
        return { canceledAt: null, startsAt: { gt: now } };
      case 'EXPIRED':
        return {
          canceledAt: null,
          OR: [{ endsAt: { lte: now } }, { usedCount: { gte: maxUses } }],
        };
      case 'ACTIVE':
        return {
          canceledAt: null,
          startsAt: { lte: now },
          endsAt: { gt: now },
          usedCount: { lt: maxUses },
        };
    }
  }

  async listForUser(filters: AuthorizationForUserFilters): Promise<{ items: AuthorizationView[]; total: number }> {
    const where: Prisma.AuthorizationWhereInput = {
      userId: filters.userId,
      ...(filters.status ? this.statusWhere(filters.status, filters.now) : {}),
    };

    const [rows, total] = await this.prisma.$transaction([
      this.prisma.authorization.findMany({
        where,
        orderBy: [{ startsAt: 'desc' }, { id: 'desc' }],
        skip: (filters.page - 1) * filters.pageSize,
        take: filters.pageSize,
        select: SELECT,
      }),
      this.prisma.authorization.count({ where }),
    ]);

    return {
      items: rows.map((row) => toAuthorizationView(toRecord(row), filters.now)),
      total,
    };
  }
}
