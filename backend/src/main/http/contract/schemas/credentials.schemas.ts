import { z } from 'zod';
import { named } from '../registry.js';
import { TerminalId } from './access-events.schemas.js';

export const ValidateQrCredentialRequest = named(
  'ValidateQrCredentialRequest',
  z.object({
    qrToken: z.string().min(1).max(2048).describe('Token assinado lido do QR do terminal'),
    terminalId: TerminalId,
  }),
);

export const ValidateQrCredentialResponse = named(
  'ValidateQrCredentialResponse',
  z.discriminatedUnion('valid', [
    z.object({ valid: z.literal(true), terminalId: TerminalId, expiresAt: z.iso.datetime() }),
    z.object({ valid: z.literal(false) }),
  ]),
  'Resultado da validacao criptografica; nao representa uma decisao de acesso',
);
