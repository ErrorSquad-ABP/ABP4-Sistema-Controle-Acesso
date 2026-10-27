import {
  authorizationStatus,
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

function toRecord(row: Row): AuthorizationRecord {
  return row;
}

export class PrismaAuthorizationRepository implements AuthorizationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async listForUser(filters: AuthorizationForUserFilters): Promise<{ items: AuthorizationView[]; total: number }> {
    // A situacao compara usedCount com maxUses (coluna com coluna), que o Prisma
    // nao expressa em `where`: filtra em memoria sobre as autorizacoes do usuario,
    // conjunto limitado pelo indice [userId, startsAt, endsAt].
    const rows = await this.prisma.authorization.findMany({
      where: { userId: filters.userId },
      orderBy: [{ startsAt: 'desc' }, { id: 'desc' }],
      select: SELECT,
    });

    const matching = rows
      .map(toRecord)
      .filter(
        (record) =>
          filters.status === undefined || authorizationStatus(record, filters.now) === filters.status,
      );

    const start = (filters.page - 1) * filters.pageSize;
    return {
      items: matching.slice(start, start + filters.pageSize).map((record) => toAuthorizationView(record, filters.now)),
      total: matching.length,
    };
  }
}
