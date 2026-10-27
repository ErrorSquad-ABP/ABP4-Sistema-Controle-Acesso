import { z } from 'zod';
import { TERMINAL_ID_PATTERN } from '../../../../shared/terminal-id.js';
import { named } from '../registry.js';
import { LocationSummary } from './authorizations.schemas.js';
import { DateTime, Id, PaginationQuery, PeriodQuery, page, refinePeriod } from './common.schemas.js';
import { UserSummary } from './users.schemas.js';

export const AccessMethod = named('AccessMethod', z.enum(['QR', 'NFC']));

export const AccessDecision = named('AccessDecision', z.enum(['GRANTED', 'DENIED']));

export const DenialReason = named(
  'DenialReason',
  z.enum([
    'INVALID_CREDENTIAL',
    'CREDENTIAL_EXPIRED',
    'USER_INACTIVE',
    'NO_AUTHORIZATION',
    'AUTHORIZATION_NOT_STARTED',
    'AUTHORIZATION_EXPIRED',
    'AUTHORIZATION_CANCELED',
    'NO_USES_LEFT',
    'OUT_OF_RANGE',
    'UNKNOWN_TERMINAL',
    'TERMINAL_INACTIVE',
  ]),
  'Motivo da negativa. CREDENTIAL_EXPIRED: QR fora da validade de 10 s · OUT_OF_RANGE: mais de 100 m do terminal',
);

export const GeoPoint = named(
  'GeoPoint',
  z.object({
    latitude: z.number().min(-90).max(90),
    longitude: z.number().min(-180).max(180),
    accuracyMeters: z.number().min(0).optional().describe('Precisao informada pelo GPS do aparelho'),
  }),
);

/** Mesmo id usado nos topicos MQTT `terminals/{id}/...` (ver contratos-mqtt.md, US-04). */
export const TerminalId = z
  .string()
  .regex(TERMINAL_ID_PATTERN, 'Use letras minusculas, numeros e hifen (ate 64)')
  .describe('Identificador do terminal (ex.: "aurora-recepcao"); deve bater com o terminal do token');

export const AccessEvent = named(
  'AccessEvent',
  z.object({
    id: Id,
    occurredAt: DateTime,
    terminalId: TerminalId.nullable().describe('Identificador recebido; null em eventos legados'),
    method: AccessMethod,
    decision: AccessDecision,
    reason: DenialReason.nullable().describe('null quando GRANTED'),
    user: UserSummary.nullable().describe('null quando a credencial nao identifica ninguem (ex.: tag NFC desconhecida)'),
    location: LocationSummary.nullable().describe('null quando o terminal nao possui local resolvido'),
    authorizationId: Id.nullable(),
    distanceMeters: z.number().min(0).nullable().describe('Distancia ate o terminal (so no fluxo QR)'),
  }),
  'Tentativa de acesso registrada, aceita ou negada',
);

export const AccessEventPage = page('AccessEventPage', AccessEvent);

export const QrAccessRequest = named(
  'QrAccessRequest',
  z.object({
    qrToken: z.string().min(1).max(2048).describe('Conteudo lido do QR exibido no terminal'),
    terminalId: TerminalId,
    // Sem .describe(): ele cria uma copia fora do registry e o $ref se perde.
    position: GeoPoint,
    requestId: Id.optional().describe(
      'Chave de idempotencia da tentativa: repetir o mesmo valor devolve o mesmo evento e o mesmo comando',
    ),
  }),
);

export const AccessResult = named(
  'AccessResult',
  z.object({
    decision: AccessDecision,
    reason: DenialReason.nullable(),
    message: z.string().describe('Texto para a tela de resultado (ex.: "Autorizacao expirada")'),
    event: AccessEvent,
  }),
  'Resultado da tentativa. Negar acesso NAO e erro HTTP: volta 200 com decision=DENIED',
);

export const ListMyAccessEventsQuery = PaginationQuery.extend({
  ...PeriodQuery.shape,
}).superRefine(refinePeriod);

export const ListAccessEventsQuery = PaginationQuery.extend({
  userId: Id.optional(),
  locationId: Id.optional(),
  method: AccessMethod.optional(),
  decision: AccessDecision.optional(),
  ...PeriodQuery.shape,
}).superRefine(refinePeriod);
