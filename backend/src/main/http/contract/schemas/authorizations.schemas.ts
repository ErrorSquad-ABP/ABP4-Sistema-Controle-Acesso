import { z } from 'zod';
import { named } from '../registry.js';
import { DateTime, Id, PaginationQuery, PeriodQuery, page, refinePeriod } from './common.schemas.js';
import { UserSummary } from './users.schemas.js';

export const AuthorizationStatus = named(
  'AuthorizationStatus',
  z.enum(['SCHEDULED', 'ACTIVE', 'EXPIRED', 'CANCELED']),
  'SCHEDULED: antes da janela · ACTIVE: dentro da janela e com usos · ' +
    'EXPIRED: janela encerrada ou usos esgotados · CANCELED: cancelada pelo administrador',
);

export const LocationSummary = named(
  'LocationSummary',
  z.object({
    id: Id,
    name: z.string().describe('Ex.: "Edificio Aurora · Recepcao"'),
  }),
);

export const Authorization = named(
  'Authorization',
  z.object({
    id: Id,
    user: UserSummary,
    location: LocationSummary,
    startsAt: DateTime,
    endsAt: DateTime,
    maxUses: z.int().min(1),
    usedCount: z.int().min(0),
    remainingUses: z.int().min(0),
    status: AuthorizationStatus,
    canceledAt: DateTime.nullable(),
    cancelReason: z.string().nullable(),
    createdAt: DateTime,
  }),
  'Pessoa + local + janela de horario + numero de utilizacoes + situacao',
);

export const AuthorizationPage = page('AuthorizationPage', Authorization);

export const CreateAuthorizationRequest = named(
  'CreateAuthorizationRequest',
  z
    .object({
      userId: Id,
      locationId: Id,
      startsAt: DateTime,
      endsAt: DateTime,
      maxUses: z.int().min(1).max(1000).describe('Numero de utilizacoes permitidas na janela'),
    })
    .strict()
    .refine((v) => Date.parse(v.endsAt) > Date.parse(v.startsAt), {
      path: ['endsAt'],
      message: '`endsAt` deve ser posterior a `startsAt`',
    }),
);

export const CancelAuthorizationRequest = named(
  'CancelAuthorizationRequest',
  z.object({
    reason: z.string().trim().min(1).max(280).optional().describe('Motivo exibido no historico'),
  }),
);

export const ListMyAuthorizationsQuery = PaginationQuery.extend({
  status: AuthorizationStatus.optional(),
});

export const ListAuthorizationsQuery = PaginationQuery.extend({
  userId: Id.optional(),
  locationId: Id.optional(),
  status: AuthorizationStatus.optional(),
  ...PeriodQuery.shape,
}).superRefine(refinePeriod);
