import type { ListLocationsFilters, LocationRepository } from '../../domain/ports/location-repository.js';
import { toLocationView, type LocationView } from './location-view.js';

export interface LocationPageView {
  items: LocationView[];
  page: number;
  pageSize: number;
  total: number;
}

export class ListLocationsUseCase {
  constructor(private readonly locations: LocationRepository) {}

  async execute(filters: ListLocationsFilters): Promise<LocationPageView> {
    const { items, total } = await this.locations.listActive(filters);
    return {
      items: items.map(toLocationView),
      page: filters.page,
      pageSize: filters.pageSize,
      total,
    };
  }
}
