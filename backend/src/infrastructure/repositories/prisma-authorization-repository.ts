import {
  toAuthorizationView,
  type AuthorizationRecord,
  type AuthorizationView,
} from '../../domain/authorizations/authorization.js';
import type {
  AuthorizationAdminFilters,
  AuthorizationForUserFilters,
  AuthorizationRepository,
  NewAuthorization,
} from '../../domain/ports/authorization-repository.js';
import { ConflictError, ValidationError } from '../../domain/errors/domain-error.js';
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

  async list(filters: AuthorizationAdminFilters): Promise<{ items: AuthorizationView[]; total: number }> {
    // `AND` evita que o status (que tambem usa `startsAt`) sobrescreva o periodo.
    const where: Prisma.AuthorizationWhereInput = {
      AND: [
        ...(filters.userId ? [{ userId: filters.userId }] : []),
        ...(filters.locationId ? [{ locationId: filters.locationId }] : []),
        ...(filters.from || filters.to
          ? [{ startsAt: { ...(filters.from ? { gte: filters.from } : {}), ...(filters.to ? { lte: filters.to } : {}) } }]
          : []),
        ...(filters.status ? [this.statusWhere(filters.status, filters.now)] : []),
      ],
    };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.authorization.findMany({ where, orderBy: [{ startsAt: 'desc' }, { id: 'desc' }], skip: (filters.page - 1) * filters.pageSize, take: filters.pageSize, select: SELECT }),
      this.prisma.authorization.count({ where }),
    ]);
    return { items: rows.map((row) => toAuthorizationView(toRecord(row), filters.now)), total };
  }

  async findById(id: string): Promise<AuthorizationRecord | null> {
    const row = await this.prisma.authorization.findUnique({ where: { id }, select: SELECT });
    return row ? toRecord(row) : null;
  }

  async create(input: NewAuthorization): Promise<AuthorizationRecord> {
    const [user, location] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: input.userId }, select: { id: true, active: true } }),
      this.prisma.accessLocation.findUnique({ where: { id: input.locationId }, select: { id: true, isActive: true } }),
    ]);
    if (!user?.active) throw new ValidationError('Pessoa inexistente ou inativa');
    if (!location?.isActive) throw new ValidationError('Local inexistente ou inativo');
    try {
      const row = await this.prisma.authorization.create({ data: input, select: SELECT });
      return toRecord(row);
    } catch (err) {
      if ((err as { code?: string }).code === 'P2003') throw new ValidationError('Pessoa ou local inexistente');
      throw err;
    }
  }

  async cancel(id: string, at: Date, reason: string | null): Promise<AuthorizationRecord | null> {
    // Escrita condicional: duas requisicoes concorrentes nao podem cancelar a mesma
    // autorizacao nem sobrescrever o motivo; o perdedor da corrida leva 409.
    const { count } = await this.prisma.authorization.updateMany({
      where: {
        id,
        canceledAt: null,
        endsAt: { gt: at },
        usedCount: { lt: this.prisma.authorization.fields.maxUses },
      },
      data: { canceledAt: at, cancelReason: reason },
    });

    if (count === 0) {
      if (!(await this.prisma.authorization.findUnique({ where: { id }, select: { id: true } }))) return null;
      throw new ConflictError('Autorizacao cancelada ou expirada nao pode ser cancelada');
    }

    const row = await this.prisma.authorization.findUniqueOrThrow({ where: { id }, select: SELECT });
    return toRecord(row);
  }
}
