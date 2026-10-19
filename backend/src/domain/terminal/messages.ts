/**
 * Mensagens do contrato MQTT v1 (docs/architecture/contratos-mqtt.md).
 * Tipos puros: validacao do payload bruto fica em infrastructure/mqtt.
 */
export const CONTRACT_VERSION = 1;

export const CHANNELS = ['qr', 'access-events', 'status', 'commands', 'acks'] as const;
export type Channel = (typeof CHANNELS)[number];

/** Validade do QR rotativo e do comando de abertura (ms). */
export const QR_TTL_MS = 10_000;
export const COMMAND_TTL_MS = 10_000;

interface Envelope {
  readonly v: typeof CONTRACT_VERSION;
  readonly messageId: string;
  readonly terminalId: string;
  readonly timestamp: string;
}

export interface QrCodeMessage extends Envelope {
  readonly token: string;
  readonly expiresAt: string;
}

export interface AccessEventMessage extends Envelope {
  readonly type: 'nfc_read';
  readonly uid: string;
}

export interface StatusMessage extends Envelope {
  readonly state: 'online' | 'offline';
  readonly firmware?: string | undefined;
}

export type CommandAction = 'open' | 'deny';

export interface CommandMessage extends Envelope {
  readonly commandId: string;
  readonly expiresAt: string;
  readonly action: CommandAction;
  readonly reason?: string | undefined;
}

export type AckStatus = 'executed' | 'rejected' | 'expired';

export interface AckMessage extends Envelope {
  readonly commandId: string;
  readonly status: AckStatus;
  readonly reason?: string | undefined;
}

export interface MessagesByChannel {
  qr: QrCodeMessage;
  'access-events': AccessEventMessage;
  status: StatusMessage;
  commands: CommandMessage;
  acks: AckMessage;
}

export type TerminalMessage = MessagesByChannel[Channel];

export function isExpired(expiresAt: string, now: Date): boolean {
  return Date.parse(expiresAt) <= now.getTime();
}
