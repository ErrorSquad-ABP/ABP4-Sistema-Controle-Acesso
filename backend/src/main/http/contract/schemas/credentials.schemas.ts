import { z } from 'zod';
import { named } from '../registry.js';
import { TerminalId } from './access-events.schemas.js';

export const ValidateQrCredentialRequest = named(
  'ValidateQrCredentialRequest',
  z.union([
    z.object({
      qrToken: z
        .string()
        .min(1)
        .max(2048)
        .refine((value) => !/^[0-9]{41}$/.test(value), 'token compacto exige terminalCode')
        .describe('Token assinado lido do QR textual do terminal'),
      terminalId: TerminalId,
      terminalCode: z.never().optional(),
    }),
    z.object({
      qrToken: z.string().regex(/^[0-9]{41}$/).describe('Token compacto de 41 digitos'),
      terminalCode: z.number().int().min(1).max(255).describe('Codigo curto provisionado para o terminal'),
      terminalId: z.never().optional(),
    }),
  ]),
  'Token e referencia do terminal: terminalId legado ou terminalCode compacto, nunca os dois',
);

export const ValidateQrCredentialResponse = named(
  'ValidateQrCredentialResponse',
  z.discriminatedUnion('valid', [
    z.object({ valid: z.literal(true), terminalId: TerminalId, expiresAt: z.iso.datetime() }),
    z.object({ valid: z.literal(false) }),
  ]),
  'Resultado da validacao criptografica; nao representa uma decisao de acesso',
);
