import { ConflictError } from '../../domain/errors/domain-error.js';
import type {
  NewUserRecord,
  UserAdminRepository,
  UserChanges,
  UserListFilters,
} from '../../domain/ports/user-admin-repository.js';
import type { UserRecord } from '../../domain/ports/user-repository.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';
import { USER_SELECT } from './prisma-user-repository.js';

function isPrismaError(err: unknown, code: string): boolean {
  return (err as { code?: unknown } | null)?.code === code;
}

export class PrismaUserAdminRepository implements UserAdminRepository {
  constructor(private readonly prisma: PrismaClient) {}

  findByEmail(email: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { email: email.toLowerCase() }, select: USER_SELECT });
  }

  findById(id: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { id }, select: USER_SELECT });
  }

  async list(filters: UserListFilters): Promise<{ items: UserRecord[]; total: number }> {
    const where: Prisma.UserWhereInput = {};
    if (filters.role) where.role = filters.role;
    if (filters.active !== undefined) where.active = filters.active;
    if (filters.search) {
      where.OR = [
        { name: { contains: filters.search, mode: 'insensitive' } },
        { email: { contains: filters.search, mode: 'insensitive' } },
      ];
    }

    const [items, total] = await this.prisma.$transaction([
      this.prisma.user.findMany({
        where,
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
        skip: (filters.page - 1) * filters.pageSize,
        take: filters.pageSize,
        select: USER_SELECT,
      }),
      this.prisma.user.count({ where }),
    ]);
    return { items, total };
  }

  async create(user: NewUserRecord): Promise<UserRecord> {
    try {
      return await this.prisma.user.create({ data: user, select: USER_SELECT });
    } catch (err) {
      // Corrida entre dois cadastros do mesmo e-mail: a unique do banco decide.
      if (isPrismaError(err, 'P2002')) throw new ConflictError('E-mail ja cadastrado');
      throw err;
    }
  }

  async update(id: string, changes: UserChanges): Promise<UserRecord | null> {
    const data: Prisma.UserUpdateInput = {};
    if (changes.name !== undefined) data.name = changes.name;
    if (changes.email !== undefined) data.email = changes.email;
    if (changes.passwordHash !== undefined) data.passwordHash = changes.passwordHash;
    if (changes.role !== undefined) data.role = changes.role;
    if (changes.active !== undefined) data.active = changes.active;

    try {
      return await this.prisma.user.update({ where: { id }, data, select: USER_SELECT });
    } catch (err) {
      if (isPrismaError(err, 'P2025')) return null;
      if (isPrismaError(err, 'P2002')) throw new ConflictError('E-mail ja cadastrado');
      throw err;
    }
  }
}
