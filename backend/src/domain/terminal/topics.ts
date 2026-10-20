import { TERMINAL_ID_PATTERN } from '../../shared/terminal-id.js';
import { CHANNELS, type Channel } from './messages.js';

/** Entrega por canal (QoS e retain) conforme o contrato MQTT v1. */
export const CHANNEL_DELIVERY: Readonly<Record<Channel, { qos: 0 | 1; retain: boolean }>> = {
  qr: { qos: 0, retain: false },
  'access-events': { qos: 1, retain: false },
  status: { qos: 1, retain: true },
  commands: { qos: 1, retain: false },
  acks: { qos: 1, retain: false },
};

export function topicFor(channel: Channel, terminalId: string): string {
  return `terminals/${terminalId}/${channel}`;
}

/** Filtro com wildcard para assinar um canal de todos os terminais. */
export function topicFilterFor(channel: Channel): string {
  return `terminals/+/${channel}`;
}

export interface ParsedTopic {
  readonly terminalId: string;
  readonly channel: Channel;
}

export function parseTopic(topic: string): ParsedTopic | undefined {
  const [root, terminalId, channel, ...rest] = topic.split('/');
  if (root !== 'terminals' || rest.length > 0 || !terminalId || !channel) return undefined;
  if (!TERMINAL_ID_PATTERN.test(terminalId)) return undefined;
  const known = CHANNELS.find((c) => c === channel);
  return known ? { terminalId, channel: known } : undefined;
}
