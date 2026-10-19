import { describe, expect, it } from 'vitest';
import type { CommandMessage } from '../../src/domain/terminal/messages.js';
import { PendingCommands } from '../../src/domain/terminal/pending-commands.js';
import { SeenMessages } from '../../src/domain/terminal/seen-messages.js';
import { parseTopic, topicFilterFor, topicFor } from '../../src/domain/terminal/topics.js';
import { NOW, UUID_CMD, envelope } from '../support/terminal-fakes.js';

describe('topics', () => {
  it('monta e interpreta topicos de ida e volta', () => {
    expect(topicFor('commands', 'terminal-01')).toBe('terminals/terminal-01/commands');
    expect(parseTopic('terminals/terminal-01/acks')).toEqual({
      terminalId: 'terminal-01',
      channel: 'acks',
    });
    expect(topicFilterFor('status')).toBe('terminals/+/status');
  });

  it.each([
    'terminals/terminal-01',
    'terminals/terminal-01/desconhecido',
    'terminals/TERMINAL/acks',
    'devices/terminal-01/acks',
    'terminals/terminal-01/acks/extra',
  ])('ignora topico invalido %s', (topic) => {
    expect(parseTopic(topic)).toBeUndefined();
  });
});

describe('SeenMessages', () => {
  it('aceita o id uma vez e rejeita a repeticao', () => {
    const seen = new SeenMessages();

    expect(seen.markIfNew('a')).toBe(true);
    expect(seen.markIfNew('a')).toBe(false);
  });

  it('esquece o id mais antigo quando passa da capacidade', () => {
    const seen = new SeenMessages(2);
    seen.markIfNew('a');
    seen.markIfNew('b');
    seen.markIfNew('c');

    expect(seen.markIfNew('a')).toBe(true);
    expect(seen.markIfNew('c')).toBe(false);
  });
});

describe('PendingCommands', () => {
  const command: CommandMessage = {
    ...envelope(),
    commandId: UUID_CMD,
    expiresAt: '2026-10-19T19:30:10.000Z',
    action: 'open',
  };

  it('devolve o comando uma unica vez', () => {
    const pending = new PendingCommands();
    pending.register(command, NOW);

    expect(pending.take(UUID_CMD)).toEqual(command);
    expect(pending.take(UUID_CMD)).toBeUndefined();
  });

  it('descarta comandos vencidos ha mais que a folga ao registrar o proximo', () => {
    const pending = new PendingCommands(60_000);
    pending.register(command, NOW);
    const later = new Date(Date.parse(command.expiresAt) + 60_000);

    pending.register({ ...command, commandId: 'c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c02' }, later);

    expect(pending.size).toBe(1);
    expect(pending.take(UUID_CMD)).toBeUndefined();
  });
});
