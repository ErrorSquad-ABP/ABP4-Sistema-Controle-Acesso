import { describe, expect, it } from 'vitest';
import { CreateAuthorizationUseCase } from '../../src/application/authorizations/create-authorization.use-case.js';
import { ValidationError } from '../../src/domain/errors/domain-error.js';
import type {
  AuthorizationLocation,
  AuthorizationRepository,
  AuthorizationUser,
  CreatedAuthorization,
  NewAuthorization,
} from '../../src/domain/ports/authorization-repository.js';
import type { Clock } from '../../src/domain/ports/clock.js';
import type { IdGenerator } from '../../src/domain/ports/id-generator.js';

const NOW = new Date('2026-10-25T12:00:00.000Z');
const USER_ID = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
const LOCATION_ID = '1b4e28ba-2fa1-41d2-883f-0016d3cca427';
const ADMIN_ID = 'e2e7e6b0-6d2f-49d3-8a13-94c8482b9a01';
const AUTHORIZATION_ID = 'f8fcf70f-a886-4693-9863-c6c19703e521';

class FixedClock implements Clock {
  constructor(private readonly instant: Date) {}
  now(): Date { return new Date(this.instant); }
}

class FixedIds implements IdGenerator {
  uuid(): string { return AUTHORIZATION_ID; }
  token(): string { return 'unused'; }
}

class FakeAuthorizationRepository implements AuthorizationRepository {
  user: AuthorizationUser | undefined = { id: USER_ID, name: 'Pessoa', role: 'RESIDENT', active: true };
  location: AuthorizationLocation | undefined = { id: LOCATION_ID, name: 'Recepcao', isActive: true };
  created: NewAuthorization[] = [];

  async findUserById(id: string) { return this.user?.id === id ? this.user : undefined; }
  async findLocationById(id: string) { return this.location?.id === id ? this.location : undefined; }
  async create(input: NewAuthorization): Promise<CreatedAuthorization> {
    this.created.push(input);
    return { ...input, user: this.user!, location: this.location! };
  }
}

const validInput = {
  userId: USER_ID,
  locationId: LOCATION_ID,
  startsAt: new Date('2026-10-25T13:00:00.000Z'),
  endsAt: new Date('2026-10-25T18:00:00.000Z'),
  maxUses: 5,
  createdById: ADMIN_ID,
};

describe('CreateAuthorizationUseCase', () => {
  it('cria com fatos controlados pelo servidor e calcula a situacao usando o Clock', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new CreateAuthorizationUseCase(repository, new FixedClock(NOW), new FixedIds());

    const result = await useCase.execute(validInput);

    expect(repository.created).toEqual([{
      id: AUTHORIZATION_ID,
      userId: USER_ID,
      locationId: LOCATION_ID,
      createdById: ADMIN_ID,
      startsAt: validInput.startsAt,
      endsAt: validInput.endsAt,
      maxUses: 5,
      usedCount: 0,
      canceledAt: null,
      cancelReason: null,
      createdAt: NOW,
    }]);
    expect(result).toMatchObject({
      id: AUTHORIZATION_ID,
      status: 'SCHEDULED',
      usedCount: 0,
      remainingUses: 5,
      canceledAt: null,
      cancelReason: null,
      createdAt: NOW,
    });
  });

  it('rejeita periodo em que endsAt nao e posterior a startsAt antes de consultar ou gravar', async () => {
    const repository = new FakeAuthorizationRepository();
    const useCase = new CreateAuthorizationUseCase(repository, new FixedClock(NOW), new FixedIds());

    await expect(useCase.execute({ ...validInput, endsAt: validInput.startsAt }))
      .rejects.toBeInstanceOf(ValidationError);
    expect(repository.created).toHaveLength(0);
  });

  it.each(['ADMIN', 'RESIDENT', 'VISITOR'] as const)(
    'aceita pessoa existente do papel %s, mesmo inativa, e local existente inativo',
    async (role) => {
      const repository = new FakeAuthorizationRepository();
      repository.user = { id: USER_ID, name: 'Pessoa', role, active: false };
      repository.location = { id: LOCATION_ID, name: 'Recepcao', isActive: false };
      const useCase = new CreateAuthorizationUseCase(repository, new FixedClock(NOW), new FixedIds());

      const result = await useCase.execute(validInput);

      expect(result.user.role).toBe(role);
      expect(repository.created).toHaveLength(1);
    },
  );

  it('rejeita pessoa ou local inexistente', async () => {
    const repository = new FakeAuthorizationRepository();
    repository.user = undefined;
    repository.location = undefined;
    const useCase = new CreateAuthorizationUseCase(repository, new FixedClock(NOW), new FixedIds());

    await expect(useCase.execute(validInput)).rejects.toMatchObject({
      code: 'VALIDATION_ERROR',
      details: { userId: ['Pessoa inexistente'], locationId: ['Local inexistente'] },
    });
    expect(repository.created).toHaveLength(0);
  });
});
