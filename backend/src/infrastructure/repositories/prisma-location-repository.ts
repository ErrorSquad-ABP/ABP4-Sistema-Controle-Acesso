import type {
  ListLocationsFilters,
  LocationRecord,
  LocationRepository,
  NewLocationRecord,
} from '../../domain/ports/location-repository.js';
import type { Prisma, PrismaClient } from '../../generated/prisma/client.js';

const SELECT = {
  id: true,
  name: true,
  description: true,
  latitude: true,
  longitude: true,
  radiusMeters: true,
  isActive: true,
  createdAt: true,
  updatedAt: true,
} as const;

type Row = Prisma.AccessLocationGetPayload<{ select: typeof SELECT }>;

// O Prisma devolve Decimal nas coordenadas; o contrato trabalha com number.
const toRecord = (row: Row): LocationRecord => ({
  ...row,
  latitude: Number(row.latitude),
  longitude: Number(row.longitude),
});

export class PrismaLocationRepository implements LocationRepository {
  constructor(private readonly prisma: PrismaClient) {}

  async listActive(filters: ListLocationsFilters): Promise<{ items: LocationRecord[]; total: number }> {
    const where: Prisma.AccessLocationWhereInput = { isActive: true };
    const [rows, total] = await this.prisma.$transaction([
      this.prisma.accessLocation.findMany({
        where,
        orderBy: [{ name: 'asc' }, { id: 'asc' }],
        skip: (filters.page - 1) * filters.pageSize,
        take: filters.pageSize,
        select: SELECT,
      }),
      this.prisma.accessLocation.count({ where }),
    ]);
    return { items: rows.map(toRecord), total };
  }

  async create(location: NewLocationRecord): Promise<LocationRecord> {
    const row = await this.prisma.accessLocation.create({
      data: { ...location, isActive: true },
      select: SELECT,
    });
    return toRecord(row);
  }
}
