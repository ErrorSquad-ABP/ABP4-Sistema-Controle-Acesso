import { describe, expect, it } from 'vitest';
import { CreateLocationUseCase } from '../../src/application/locations/create-location.use-case.js';
import { ListLocationsUseCase } from '../../src/application/locations/list-locations.use-case.js';
import { ValidationError } from '../../src/domain/errors/domain-error.js';
import type { LocationRecord } from '../../src/domain/ports/location-repository.js';
import { InMemoryLocationRepository } from '../support/in-memory-locations.js';

const reception: LocationRecord = {
  id: '1b4e28ba-2fa1-41d2-883f-0016d3cca427',
  name: 'Edificio Aurora - Recepcao',
  description: 'Av. Central, 1200',
  latitude: -23.1857,
  longitude: -45.8846,
  radiusMeters: 100,
  isActive: true,
  createdAt: new Date('2026-01-01T00:00:00Z'),
  updatedAt: new Date('2026-01-01T00:00:00Z'),
};

const garage: LocationRecord = {
  ...reception,
  id: '2b4e28ba-2fa1-41d2-883f-0016d3cca428',
  name: 'Edificio Aurora - Garagem',
  description: null,
  isActive: false,
};

describe('ListLocationsUseCase', () => {
  it('lista so os ativos, em ordem alfabetica e de forma paginada', async () => {
    const third: LocationRecord = { ...reception, id: '3b4e28ba-2fa1-41d2-883f-0016d3cca429', name: 'Zeladoria' };
    const locations = new InMemoryLocationRepository([third, reception, garage]);
    const list = new ListLocationsUseCase(locations);

    const all = await list.execute({ page: 1, pageSize: 20 });
    expect(all.total).toBe(2);
    expect(all.items.map((location) => location.name)).toEqual([
      'Edificio Aurora - Recepcao',
      'Zeladoria',
    ]);
    expect(all).toMatchObject({ page: 1, pageSize: 20 });
    expect(all.items[0]?.createdAt).toBe('2026-01-01T00:00:00.000Z');

    const page2 = await list.execute({ page: 2, pageSize: 1 });
    expect(page2).toMatchObject({ page: 2, pageSize: 1, total: 2 });
    expect(page2.items).toHaveLength(1);
  });
});

describe('CreateLocationUseCase', () => {
  it('cria ativo, com descricao opcional e datas ISO', async () => {
    const locations = new InMemoryLocationRepository();

    const created = await new CreateLocationUseCase(locations).execute({
      name: 'Edificio Aurora - Recepcao',
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 40,
    });

    expect(created).toMatchObject({
      name: 'Edificio Aurora - Recepcao',
      description: null,
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 40,
      isActive: true,
    });
    expect(created.createdAt).toBe(created.updatedAt);
    expect((await locations.listActive({ page: 1, pageSize: 20 })).total).toBe(1);
  });

  it('recusa raio fora de 1..100 e nao inteiro (DT-23)', async () => {
    const create = new CreateLocationUseCase(new InMemoryLocationRepository());
    const base = {
      name: 'Edificio Aurora',
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 100,
    };

    for (const radiusMeters of [0, -1, 101, 50.5, Number.NaN]) {
      await expect(create.execute({ ...base, radiusMeters })).rejects.toBeInstanceOf(ValidationError);
    }
  });
});
