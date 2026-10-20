import { z } from 'zod';
import { named } from '../registry.js';
import { User } from './users.schemas.js';

export const LoginRequest = named(
  'LoginRequest',
  z.object({
    email: z.email().max(254).transform((v) => v.toLowerCase()),
    password: z.string().min(1).max(72),
  }),
);

export const LoginResponse = named(
  'LoginResponse',
  z.object({
    accessToken: z.string().describe('JWT para o header `Authorization: Bearer <token>`'),
    tokenType: z.literal('Bearer'),
    expiresIn: z.int().min(1).describe('Validade do token, em segundos'),
    user: User,
  }),
);
