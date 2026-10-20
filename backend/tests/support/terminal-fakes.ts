import type { Clock } from '../../src/domain/ports/clock.js';
import type { IdGenerator } from '../../src/domain/ports/id-generator.js';
import type { MessageBus } from '../../src/domain/ports/message-bus.js';
import type { Channel, MessagesByChannel } from '../../src/domain/terminal/messages.js';
import { createLogger, type Logger } from '../../src/shared/logger.js';

export class FixedClock implements Clock {
  constructor(public date: Date) {}
  now(): Date {
    return this.date;
  }
}

/** Ids previsiveis: 00000000-0000-4000-8000-000000000001, ...002 */
export class SequentialIds implements IdGenerator {
  private n = 0;
  uuid(): string {
    this.n += 1;
    return `00000000-0000-4000-8000-${String(this.n).padStart(12, '0')}`;
  }
  token(): string {
    return 'tokentest123';
  }
}

export class RecordingBus implements MessageBus {
  readonly published: { channel: Channel; message: MessagesByChannel[Channel] }[] = [];
  publish<C extends Channel>(channel: C, message: MessagesByChannel[C]): Promise<void> {
    this.published.push({ channel, message });
    return Promise.resolve();
  }
}

export const silentLogger: Logger = createLogger('silent');

export const NOW = new Date('2026-10-19T19:30:00.000Z');
export const TERMINAL = 'terminal-01';
export const UUID_A = '3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10';
export const UUID_B = '9a6d1b52-3d0e-4d8e-a2b5-1c7f0e4a8b21';
export const UUID_CMD = 'c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c01';

export function envelope(messageId = UUID_A, terminalId = TERMINAL) {
  return { v: 1 as const, messageId, terminalId, timestamp: NOW.toISOString() };
}
