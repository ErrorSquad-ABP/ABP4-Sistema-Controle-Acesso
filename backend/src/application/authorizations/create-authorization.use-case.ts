import { ValidationError } from '../../domain/errors/domain-error.js';
import { authorizationStatus, validateAuthorizationPeriod } from '../../domain/authorization/authorization.js';
import type { AuthorizationRepository, NewAuthorization } from '../../domain/ports/authorization-repository.js';
import type { Clock } from '../../domain/ports/clock.js';
import type { IdGenerator } from '../../domain/ports/id-generator.js';

export interface CreateAuthorizationInput {
  userId: string;
  locationId: string;
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  createdById: string;
}

export interface CreateAuthorizationOutput {
  id: string;
  user: { id: string; name: string; role: 'ADMIN' | 'RESIDENT' | 'VISITOR' };
  location: { id: string; name: string };
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  remainingUses: number;
  status: ReturnType<typeof authorizationStatus>;
  canceledAt: Date | null;
  cancelReason: string | null;
  createdAt: Date;
}

/** Cria autorização para qualquer pessoa e local existentes, independentemente de estarem ativos. */
export class CreateAuthorizationUseCase {
  constructor(
    private readonly authorizations: AuthorizationRepository,
    private readonly clock: Clock,
    private readonly ids: IdGenerator,
  ) {}

  async execute(input: CreateAuthorizationInput): Promise<CreateAuthorizationOutput> {
    validateAuthorizationPeriod(input.startsAt, input.endsAt, input.maxUses);

    const [user, location] = await Promise.all([
      this.authorizations.findUserById(input.userId),
      this.authorizations.findLocationById(input.locationId),
    ]);
    if (!user || !location) {
      throw new ValidationError('Pessoa ou local inexistente', {
        ...(!user ? { userId: ['Pessoa inexistente'] } : {}),
        ...(!location ? { locationId: ['Local inexistente'] } : {}),
      });
    }

    const now = this.clock.now();
    const facts: NewAuthorization = {
      id: this.ids.uuid(),
      userId: user.id,
      locationId: location.id,
      createdById: input.createdById,
      startsAt: input.startsAt,
      endsAt: input.endsAt,
      maxUses: input.maxUses,
      usedCount: 0,
      canceledAt: null,
      cancelReason: null,
      createdAt: now,
    };
    const created = await this.authorizations.create(facts);

    return {
      id: created.id,
      user: { id: created.user.id, name: created.user.name, role: created.user.role },
      location: { id: created.location.id, name: created.location.name },
      startsAt: created.startsAt,
      endsAt: created.endsAt,
      maxUses: created.maxUses,
      usedCount: created.usedCount,
      remainingUses: created.maxUses - created.usedCount,
      status: authorizationStatus(created, now),
      canceledAt: created.canceledAt,
      cancelReason: created.cancelReason,
      createdAt: created.createdAt,
    };
  }
}
