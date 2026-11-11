import { z } from 'zod';
import { named } from '../registry.js';
import { DateTime, Id, page } from './common.schemas.js';

const Name = z.string().trim().min(2).max(120);
const Description = z.string().trim().min(1).max(200);

/** Teto de 100 m da DT-23, repetido na CHECK `AccessLocation_radiusMeters_check`. */
const RadiusMeters = z.int().min(1).max(100);

export const Location = named(
  'Location',
  z.object({
    id: Id,
    name: z.string(),
    description: z.string().nullable(),
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    radiusMeters: RadiusMeters.describe('Raio de acesso em metros (1 a 100)'),
    isActive: z.boolean(),
    createdAt: DateTime,
    updatedAt: DateTime,
  }),
);

export const LocationPage = page('LocationPage', Location);

export const CreateLocationRequest = named(
  'CreateLocationRequest',
  z.object({
    name: Name,
    description: Description.optional(),
    latitude: z.number().min(-90).max(90).describe('Latitude em graus decimais'),
    longitude: z.number().min(-180).max(180).describe('Longitude em graus decimais'),
    radiusMeters: RadiusMeters.default(100).describe('Raio de acesso em metros (1 a 100, teto da DT-23)'),
  }),
);
