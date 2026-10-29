import type { UserRole } from '../../src/domain/user-role.js';
import type { Prisma, PrismaClient } from '../../src/generated/prisma/client.js';

export interface FakeAuthorizationRow {
  id: string;
  userId: string;
  locationId: string;
  startsAt: Date;
  endsAt: Date;
  maxUses: number;
  usedCount: number;
  canceledAt: Date | null;
  cancelReason: string | null;
  createdAt: Date;
  user: { id: string; name: string; role: UserRole };
  location: { id: string; name: string };
}

interface FieldRef {
  name: string;
}

const isFieldRef = (value: unknown): value is FieldRef =>
  typeof value === 'object' && value !== null && 'name' in value && !(value instanceof Date);

const asEpoch = (value: unknown): number =>
  value instanceof Date ? value.getTime() : (value as number);

const toWhereList = (condition: unknown): Prisma.AuthorizationWhereInput[] =>
  (Array.isArray(condition) ? condition : [condition]) as Prisma.AuthorizationWhereInput[];

/**
 * Subconjunto do `where` usado pelo repositorio de autorizacoes. O fake avalia
 * o filtro de verdade para o teste falhar quando as condicoes se sobrescrevem.
 */
function matches(where: Prisma.AuthorizationWhereInput, row: FakeAuthorizationRow): boolean {
  return Object.entries(where).every(([field, condition]) => {
    if (field === 'AND') return toWhereList(condition).every((item) => matches(item, row));
    if (field === 'OR') return toWhereList(condition).some((item) => matches(item, row));
    return compare((row as unknown as Record<string, unknown>)[field], condition, row);
  });
}

function compare(actual: unknown, condition: unknown, row: FakeAuthorizationRow): boolean {
  if (condition === null) return actual === null;
  if (condition instanceof Date || typeof condition !== 'object') return actual === condition;

  return Object.entries(condition as Record<string, unknown>).every(([operator, operand]) => {
    const expected = isFieldRef(operand) ? (row as unknown as Record<string, unknown>)[operand.name] : operand;
    switch (operator) {
      case 'not':
        return expected === null ? actual !== null : actual !== expected;
      case 'lt':
        return asEpoch(actual) < asEpoch(expected);
      case 'lte':
        return asEpoch(actual) <= asEpoch(expected);
      case 'gt':
        return asEpoch(actual) > asEpoch(expected);
      case 'gte':
        return asEpoch(actual) >= asEpoch(expected);
      default:
        throw new Error(`operador nao suportado no fake de Prisma: ${operator}`);
    }
  });
}

function applyOrder(rows: FakeAuthorizationRow[], orderBy: Prisma.AuthorizationOrderByWithRelationInput[]): FakeAuthorizationRow[] {
  const asText = (value: unknown): string => (value instanceof Date ? value.toISOString() : String(value));

  return [...rows].sort((a, b) => {
    for (const rule of orderBy) {
      const [field, direction] = Object.entries(rule)[0] as [keyof FakeAuthorizationRow, 'asc' | 'desc'];
      const left = asText(a[field]);
      const right = asText(b[field]);
      const result = left < right ? -1 : left > right ? 1 : 0;
      if (result !== 0) return direction === 'desc' ? -result : result;
    }
    return 0;
  });
}

/** PrismaClient minimo para exercitar `PrismaAuthorizationRepository.list` sem banco. */
export function createFakePrismaAuthorization(rows: FakeAuthorizationRow[]): PrismaClient {
  const authorization = {
    fields: { maxUses: { name: 'maxUses' } },
    findMany: async (args: {
      where: Prisma.AuthorizationWhereInput;
      orderBy: Prisma.AuthorizationOrderByWithRelationInput[];
      skip: number;
      take: number;
    }) => {
      const filtered = applyOrder(rows.filter((row) => matches(args.where, row)), args.orderBy);
      return filtered.slice(args.skip, args.skip + args.take);
    },
    count: async (args: { where: Prisma.AuthorizationWhereInput }) =>
      rows.filter((row) => matches(args.where, row)).length,
  };

  return {
    authorization,
    $transaction: async (operations: Promise<unknown>[]) => Promise.all(operations),
  } as unknown as PrismaClient;
}
