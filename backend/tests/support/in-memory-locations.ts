import { randomUUID } from 'node:crypto';
import type {
  ListLocationsFilters,
  LocationRecord,
  LocationRepository,
  NewLocationRecord,
} from '../../src/domain/ports/location-repository.js';

export class InMemoryLocationRepository implements LocationRepository {
  private readonly locations: LocationRecord[];

  constructor(locations: LocationRecord[] = []) {
    this.locations = locations.map((location) => ({ ...location }));
  }

  async listActive(filters: ListLocationsFilters): Promise<{ items: LocationRecord[]; total: number }> {
    const active = this.locations
      .filter((location) => location.isActive)
      .sort((a, b) => a.name.localeCompare(b.name) || a.id.localeCompare(b.id));

    const start = (filters.page - 1) * filters.pageSize;
    return { items: active.slice(start, start + filters.pageSize), total: active.length };
  }

  async create(location: NewLocationRecord): Promise<LocationRecord> {
    const now = new Date();
    const created: LocationRecord = {
      id: randomUUID(),
      ...location,
      isActive: true,
      createdAt: now,
      updatedAt: now,
    };
    this.locations.push(created);
    return created;
  }
}
