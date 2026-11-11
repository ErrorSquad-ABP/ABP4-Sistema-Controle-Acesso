import type { LocationRecord } from '../../domain/ports/location-repository.js';

export interface LocationView {
  id: string;
  name: string;
  description: string | null;
  latitude: number;
  longitude: number;
  radiusMeters: number;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

/** Contrato devolve datas em UTC; o dominio guarda `Date`. */
export function toLocationView(location: LocationRecord): LocationView {
  return {
    id: location.id,
    name: location.name,
    description: location.description,
    latitude: location.latitude,
    longitude: location.longitude,
    radiusMeters: location.radiusMeters,
    isActive: location.isActive,
    createdAt: location.createdAt.toISOString(),
    updatedAt: location.updatedAt.toISOString(),
  };
}
