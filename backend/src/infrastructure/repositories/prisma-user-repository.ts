import type { UserRecord, UserRepository } from '../../domain/ports/user-repository.js';
import type { PrismaClient } from '../../generated/prisma/client.js';

export const USER_SELECT = {
  id: true,
  name: true,
  email: true,
  passwordHash: true,
  role: true,
  active: true,
  createdAt: true,
  updatedAt: true,
} as const;

export class PrismaUserRepository implements UserRepository {
  constructor(private readonly prisma: PrismaClient) {}

  findByEmail(email: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { email: email.toLowerCase() }, select: USER_SELECT });
  }

  findById(id: string): Promise<UserRecord | null> {
    return this.prisma.user.findUnique({ where: { id }, select: USER_SELECT });
  }
}
