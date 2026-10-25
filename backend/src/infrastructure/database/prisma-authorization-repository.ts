import { ValidationError } from '../../domain/errors/domain-error.js';
import type {
  AuthorizationLocation,
  AuthorizationRepository,
  AuthorizationUser,
  CreatedAuthorization,
  NewAuthorization,
} from '../../domain/ports/authorization-repository.js';
import type { PrismaClient } from '../../generated/prisma/client.js';

type AuthorizationPrismaClient = Pick<PrismaClient, 'user' | 'accessLocation' | 'authorization'>;

const userSummary = { id: true, name: true, role: true, active: true } as const;
const locationSummary = { id: true, name: true, isActive: true } as const;

function isForeignKeyError(error: unknown): boolean {
  return (
    typeof error === 'object' &&
    error !== null &&
    'code' in error &&
    (error as { code?: unknown }).code === 'P2003'
  );
}

/** Adapter de persistência da criação de autorização para Prisma. */
export class PrismaAuthorizationRepository implements AuthorizationRepository {
  constructor(private readonly prisma: AuthorizationPrismaClient) {}

  async findUserById(id: string): Promise<AuthorizationUser | undefined> {
    const user = await this.prisma.user.findUnique({ where: { id }, select: userSummary });
    return user ?? undefined;
  }

  async findLocationById(id: string): Promise<AuthorizationLocation | undefined> {
    const location = await this.prisma.accessLocation.findUnique({ where: { id }, select: locationSummary });
    return location ?? undefined;
  }

  async create(input: NewAuthorization): Promise<CreatedAuthorization> {
    try {
      const authorization = await this.prisma.authorization.create({
        data: {
          id: input.id,
          userId: input.userId,
          locationId: input.locationId,
          createdById: input.createdById,
          startsAt: input.startsAt,
          endsAt: input.endsAt,
          maxUses: input.maxUses,
          canceledAt: input.canceledAt,
          cancelReason: input.cancelReason,
          createdAt: input.createdAt,
          // usedCount fica no default zero do schema Prisma.
        },
        include: { user: { select: userSummary }, location: { select: locationSummary } },
      });
      return {
        id: authorization.id,
        userId: authorization.userId,
        locationId: authorization.locationId,
        createdById: input.createdById,
        startsAt: authorization.startsAt,
        endsAt: authorization.endsAt,
        maxUses: authorization.maxUses,
        usedCount: authorization.usedCount,
        canceledAt: authorization.canceledAt,
        cancelReason: authorization.cancelReason,
        createdAt: authorization.createdAt,
        user: authorization.user,
        location: authorization.location,
      };
    } catch (error) {
      // As referências são verificadas antes, mas podem ser removidas entre a leitura e a gravação.
      if (isForeignKeyError(error)) {
        throw new ValidationError('Pessoa, local ou administrador inexistente');
      }
      throw error;
    }
  }
}
