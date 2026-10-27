import { z } from 'zod';
import {
  CONTRACT_VERSION,
  isExpired,
  type Channel,
  type CommandMessage,
  type MessagesByChannel,
} from '../../domain/terminal/messages.js';
import { TERMINAL_ID_PATTERN } from '../../shared/terminal-id.js';

const envelope = {
  v: z.literal(CONTRACT_VERSION),
  messageId: z.uuid(),
  terminalId: z.string().regex(TERMINAL_ID_PATTERN),
  timestamp: z.iso.datetime(),
};

const reason = z.string().min(1).max(100).optional();

const SCHEMAS = {
  // Base64url dos claims + assinatura HMAC-SHA-256 pode exceder 128 chars.
  qr: z.object({ ...envelope, token: z.string().min(1).max(512), expiresAt: z.iso.datetime() }),
  'access-events': z.object({
    ...envelope,
    type: z.literal('nfc_read'),
    uid: z.string().regex(/^[0-9A-F]{4,20}$/),
  }),
  status: z.object({
    ...envelope,
    state: z.enum(['online', 'offline']),
    firmware: z.string().min(1).max(32).optional(),
  }),
  commands: z.object({
    ...envelope,
    commandId: z.uuid(),
    expiresAt: z.iso.datetime(),
    action: z.enum(['open', 'deny']),
    reason,
  }),
  acks: z.object({
    ...envelope,
    commandId: z.uuid(),
    status: z.enum(['executed', 'rejected', 'expired']),
    reason,
  }),
} satisfies Record<Channel, z.ZodType>;

export type ParseFailureCode =
  | 'invalid_json'
  | 'invalid_schema'
  | 'terminal_mismatch'
  | 'expired';

export type ParseResult<C extends Channel> =
  | { ok: true; message: MessagesByChannel[C] }
  | {
      ok: false;
      code: ParseFailureCode;
      reason: string;
      /** Presente quando o comando e valido mas chegou vencido (o terminal responde ACK `expired`). */
      command?: CommandMessage;
    };

export interface ParseOptions {
  /** Quando informado, comando com `expiresAt` vencido neste instante e rejeitado. */
  now?: Date;
}

/**
 * Converte o payload bruto de um canal na mensagem tipada do contrato v1.
 * Nunca lanca: payload invalido vira `ok: false` para o consumidor logar e descartar.
 */
export function parsePayload<C extends Channel>(
  channel: C,
  topicTerminalId: string,
  raw: Buffer | string,
  options: ParseOptions = {},
): ParseResult<C> {
  let json: unknown;
  try {
    json = JSON.parse(raw.toString());
  } catch {
    return { ok: false, code: 'invalid_json', reason: 'payload nao e JSON valido' };
  }

  const parsed = SCHEMAS[channel].safeParse(json);
  if (!parsed.success) {
    return { ok: false, code: 'invalid_schema', reason: z.prettifyError(parsed.error) };
  }
  const message = parsed.data as MessagesByChannel[C];

  if (message.terminalId !== topicTerminalId) {
    return {
      ok: false,
      code: 'terminal_mismatch',
      reason: `terminalId "${message.terminalId}" diferente do topico "${topicTerminalId}"`,
    };
  }

  if (channel === 'commands' && options.now) {
    const command = message as CommandMessage;
    if (isExpired(command.expiresAt, options.now)) {
      return { ok: false, code: 'expired', reason: 'comando expirado', command };
    }
  }

  return { ok: true, message };
}
