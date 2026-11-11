export interface ListLocationsFilters {
  page: number;
  pageSize: number;
}

export interface LocationRecord {
  id: string;
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  radiusMeters: number;
  isActive: boolean;
  createdAt: Date;
  updatedAt: Date;
}

/** Campos ja normalizados e validados pelo caso de uso. */
export interface NewLocationRecord {
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  radiusMeters: number;
}

export interface LocationRepository {
  /** So os ativos, em ordem alfabetica; o total conta o mesmo filtro. */
  listActive(filters: ListLocationsFilters): Promise<{ items: LocationRecord[]; total: number }>;
  create(location: NewLocationRecord): Promise<LocationRecord>;
}
