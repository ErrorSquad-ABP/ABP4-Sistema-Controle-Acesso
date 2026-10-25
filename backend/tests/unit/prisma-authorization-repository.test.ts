import { describe, expect, it, vi } from 'vitest';
import { ValidationError } from '../../src/domain/errors/domain-error.js';
import type { PrismaClient } from '../../src/generated/prisma/client.js';
import { PrismaAuthorizationRepository } from '../../src/infrastructure/database/prisma-authorization-repository.js';

const USER_ID = '7c9e6679-7425-40de-944b-e07fc1f90ae7';
const LOCATION_ID = '1b4e28ba-2fa1-41d2-883f-0016d3cca427';
const ADMIN_ID = 'e2e7e6b0-6d2f-49d3-8a13-94c8482b9a01';
const AUTHORIZATION_ID = 'f8fcf70f-a886-4693-9863-c6c19703e521';
const STARTS_AT = new Date('2026-10-25T13:00:00.000Z');
const ENDS_AT = new Date('2026-10-25T18:00:00.000Z');
const CREATED_AT = new Date('2026-10-25T12:00:00.000Z');

const createdRow = {
  id: AUTHORIZATION_ID,
  userId: USER_ID,
  locationId: LOCATION_ID,
  createdById: ADMIN_ID,
  startsAt: STARTS_AT,
  endsAt: ENDS_AT,
  maxUses: 5,
  usedCount: 0,
  canceledAt: null,
  cancelReason: null,
  createdAt: CREATED_AT,
  user: { id: USER_ID, name: 'Pessoa', role: 'VISITOR' as const, active: false },
  location: { id: LOCATION_ID, name: 'Recepcao', isActive: false },
};

function fakePrisma(overrides: Record<string, unknown> = {}): PrismaClient {
  return {
    user: { findUnique: vi.fn().mockResolvedValue(createdRow.user) },
    accessLocation: { findUnique: vi.fn().mockResolvedValue(createdRow.location) },
    authorization: { create: vi.fn().mockResolvedValue(createdRow) },
    ...overrides,
  } as unknown as PrismaClient;
}

describe('PrismaAuthorizationRepository', () => {
  it('busca existentes sem filtrar papel ou atividade', async () => {
    const prisma = fakePrisma();
    const repository = new PrismaAuthorizationRepository(prisma);

    await expect(repository.findUserById(USER_ID)).resolves.toEqual(createdRow.user);
    await expect(repository.findLocationById(LOCATION_ID)).resolves.toEqual(createdRow.location);
    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { id: USER_ID },
      select: { id: true, name: true, role: true, active: true },
    });
    expect(prisma.accessLocation.findUnique).toHaveBeenCalledWith({
      where: { id: LOCATION_ID },
      select: { id: true, name: true, isActive: true },
    });
  });

  it('grava o administrador, deixa usedCount no default e retorna pessoa e local', async () => {
    const prisma = fakePrisma();
    const repository = new PrismaAuthorizationRepository(prisma);

    const result = await repository.create({
      id: AUTHORIZATION_ID,
      userId: USER_ID,
      locationId: LOCATION_ID,
      createdById: ADMIN_ID,
      startsAt: STARTS_AT,
      endsAt: ENDS_AT,
      maxUses: 5,
      usedCount: 0,
      canceledAt: null,
      cancelReason: null,
      createdAt: CREATED_AT,
    });

    const create = vi.mocked(prisma.authorization.create);
    expect(create).toHaveBeenCalledOnce();
    const args = create.mock.calls[0]![0];
    expect(args.data).toEqual({
      id: AUTHORIZATION_ID,
      userId: USER_ID,
      locationId: LOCATION_ID,
      createdById: ADMIN_ID,
      startsAt: STARTS_AT,
      endsAt: ENDS_AT,
      maxUses: 5,
      canceledAt: null,
      cancelReason: null,
      createdAt: CREATED_AT,
    });
    expect('usedCount' in args.data).toBe(false);
    expect('status' in args.data).toBe(false);
    expect(args.include).toEqual({
      user: { select: { id: true, name: true, role: true, active: true } },
      location: { select: { id: true, name: true, isActive: true } },
    });
    expect(result).toEqual(createdRow);
  });

  it('converte violacao de FK em ValidationError para o contrato 422', async () => {
    const prisma = fakePrisma({
      authorization: { create: vi.fn().mockRejectedValue({ code: 'P2003' }) },
    });
    const repository = new PrismaAuthorizationRepository(prisma);

    await expect(repository.create({
      id: AUTHORIZATION_ID,
      userId: USER_ID,
      locationId: LOCATION_ID,
      createdById: ADMIN_ID,
      startsAt: STARTS_AT,
      endsAt: ENDS_AT,
      maxUses: 5,
      usedCount: 0,
      canceledAt: null,
      cancelReason: null,
      createdAt: CREATED_AT,
    })).rejects.toBeInstanceOf(ValidationError);
  });
});
