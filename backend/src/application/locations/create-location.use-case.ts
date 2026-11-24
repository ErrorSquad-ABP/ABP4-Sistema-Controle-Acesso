import { ValidationError } from '../../domain/errors/domain-error.js';
import type { LocationRepository } from '../../domain/ports/location-repository.js';
import { toLocationView, type LocationView } from './location-view.js';

export interface CreateLocationInput {
  name: string;
  description?: string | undefined;
  latitude: number;
  longitude: number;
  radiusMeters: number;
}

export class CreateLocationUseCase {
  constructor(private readonly locations: LocationRepository) {}

  async execute(input: CreateLocationInput): Promise<LocationView> {
    // Mesmo intervalo da CHECK do banco: a entrada nao pode ampliar o teto de 500 m.
    if (!Number.isInteger(input.radiusMeters) || input.radiusMeters < 1 || input.radiusMeters > 500) {
      throw new ValidationError('Raio deve ser um inteiro entre 1 e 500 metros');
    }

    const created = await this.locations.create({
      name: input.name,
      description: input.description ?? null,
      latitude: input.latitude,
      longitude: input.longitude,
      radiusMeters: input.radiusMeters,
    });
    return toLocationView(created);
  }
}
