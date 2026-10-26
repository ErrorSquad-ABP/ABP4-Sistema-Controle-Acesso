import { deriveAuthorizationStatus, type AuthorizationRecord } from '../../domain/authorizations/authorization.js';
import type { AuthorizationFilters, AuthorizationPageResult, AuthorizationRepository } from '../../domain/ports/authorization-repository.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

const authorizationInclude = {
  user: { select: { id: true, name: true, role: true } },
  location: { select: { id: true, name: true } },
} satisfies Prisma.AuthorizationInclude;

type AuthorizationRow = Prisma.AuthorizationGetPayload<{ include: typeof authorizationInclude }>;

function mapAuthorization(row: AuthorizationRow): AuthorizationRecord {
  return {
    id: row.id,
    userId: row.userId,
    user: row.user,
    locationId: row.locationId,
    location: row.location,
    startsAt: row.startsAt,
    endsAt: row.endsAt,
    maxUses: row.maxUses,
    usedCount: row.usedCount,
    canceledAt: row.canceledAt,
    cancelReason: row.cancelReason,
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  };
}

/** Regra de sobreposicao da janela autorizada com o periodo [from, to], mantida isolada. */
function overlapsValidityPeriod(from?: Date, to?: Date): Prisma.AuthorizationWhereInput {
  return {
    ...(to ? { startsAt: { lte: to } } : {}),
    ...(from ? { endsAt: { gte: from } } : {}),
  };
}

export class PrismaAuthorizationRepository implements AuthorizationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async list(filters: AuthorizationFilters): Promise<AuthorizationPageResult> {
    const where: Prisma.AuthorizationWhereInput = {
      ...(filters.userId ? { userId: filters.userId } : {}),
      ...(filters.locationId ? { locationId: filters.locationId } : {}),
      ...overlapsValidityPeriod(filters.from, filters.to),
    };
    if (!filters.status) {
      const [rows, total] = await Promise.all([
        this.prisma.authorization.findMany({
          where,
          include: authorizationInclude,
          orderBy: [{ startsAt: 'desc' }, { id: 'asc' }],
          skip: (filters.page - 1) * filters.pageSize,
          take: filters.pageSize,
        }),
        this.prisma.authorization.count({ where }),
      ]);
      return { items: rows.map(mapAuthorization), total };
    }

    // O status depende de comparacao entre colunas (usedCount/maxUses), nao representavel
    // pelo where tipado do Prisma. Filtramos antes de calcular total e paginar.
    const rows = await this.prisma.authorization.findMany({
      where,
      include: authorizationInclude,
      orderBy: [{ startsAt: 'desc' }, { id: 'asc' }],
    });
    const matching = rows.map(mapAuthorization).filter((record) => deriveAuthorizationStatus(record, filters.now) === filters.status);
    const offset = (filters.page - 1) * filters.pageSize;
    return { items: matching.slice(offset, offset + filters.pageSize), total: matching.length };
  }

  async findById(id: string): Promise<AuthorizationRecord | null> {
    const row = await this.prisma.authorization.findUnique({ where: { id }, include: authorizationInclude });
    return row ? mapAuthorization(row) : null;
  }

  async cancelIfUnchanged(
    record: AuthorizationRecord,
    canceledAt: Date,
    cancelReason: string | null,
  ): Promise<AuthorizationRecord | null> {
    const changed = await this.prisma.authorization.updateMany({
      where: {
        id: record.id,
        updatedAt: record.updatedAt,
        startsAt: record.startsAt,
        endsAt: record.endsAt,
        maxUses: record.maxUses,
        usedCount: record.usedCount,
        canceledAt: record.canceledAt,
        cancelReason: record.cancelReason,
      },
      data: { canceledAt, cancelReason },
    });
    return changed.count === 1 ? this.findById(record.id) : null;
  }
}
