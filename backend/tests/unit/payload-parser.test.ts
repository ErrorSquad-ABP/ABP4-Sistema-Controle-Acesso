import { describe, expect, it } from 'vitest';
import { parsePayload } from '../../src/infrastructure/mqtt/payload-parser.js';
import { NOW, TERMINAL, UUID_B, UUID_CMD, envelope } from '../support/terminal-fakes.js';

const json = (value: unknown) => JSON.stringify(value);

const nfcRead = { ...envelope(), type: 'nfc_read', uid: '04A1B2C3' };
const command = {
  ...envelope(),
  commandId: UUID_CMD,
  expiresAt: '2026-10-19T19:30:10.000Z',
  action: 'open',
  reason: 'nfc_authorized',
};

describe('parsePayload', () => {
  it('aceita payload valido de cada canal', () => {
    const qr = { ...envelope(), token: 'abc', expiresAt: command.expiresAt };
    const ack = { ...envelope(), commandId: UUID_CMD, status: 'executed' };

    expect(parsePayload('access-events', TERMINAL, json(nfcRead)).ok).toBe(true);
    expect(parsePayload('qr', TERMINAL, json(qr)).ok).toBe(true);
    expect(parsePayload('status', TERMINAL, json({ ...envelope(), state: 'online' })).ok).toBe(true);
    expect(parsePayload('commands', TERMINAL, json(command)).ok).toBe(true);
    expect(parsePayload('acks', TERMINAL, json(ack)).ok).toBe(true);
  });

  it('aceita Buffer e ignora campos desconhecidos', () => {
    const result = parsePayload('access-events', TERMINAL, Buffer.from(json({ ...nfcRead, extra: 1 })));

    expect(result).toEqual({ ok: true, message: nfcRead });
  });

  it('rejeita JSON malformado', () => {
    expect(parsePayload('status', TERMINAL, '{nao e json')).toMatchObject({
      ok: false,
      code: 'invalid_json',
    });
  });

  it.each([
    ['versao desconhecida', { ...nfcRead, v: 2 }],
    ['messageId que nao e UUID', { ...nfcRead, messageId: 'abc' }],
    ['timestamp invalido', { ...nfcRead, timestamp: 'ontem' }],
    ['uid em minusculo', { ...nfcRead, uid: '04a1b2c3' }],
    ['type desconhecido', { ...nfcRead, type: 'qr_read' }],
    ['campo obrigatorio ausente', { ...envelope(), type: 'nfc_read' }],
  ])('rejeita access-event com %s', (_caso, payload) => {
    expect(parsePayload('access-events', TERMINAL, json(payload))).toMatchObject({
      ok: false,
      code: 'invalid_schema',
    });
  });

  it('rejeita comando sem commandId ou com action invalida', () => {
    const semId: Partial<typeof command> = { ...command };
    delete semId.commandId;

    expect(parsePayload('commands', TERMINAL, json(semId))).toMatchObject({ code: 'invalid_schema' });
    expect(parsePayload('commands', TERMINAL, json({ ...command, action: 'explode' }))).toMatchObject({
      code: 'invalid_schema',
    });
  });

  it('rejeita payload cujo terminalId difere do topico', () => {
    expect(parsePayload('access-events', 'terminal-02', json(nfcRead))).toMatchObject({
      ok: false,
      code: 'terminal_mismatch',
    });
  });

  describe('expiracao do comando', () => {
    it('aceita comando dentro da validade', () => {
      const now = new Date('2026-10-19T19:30:09.999Z');

      expect(parsePayload('commands', TERMINAL, json(command), { now }).ok).toBe(true);
    });

    it('rejeita comando exatamente no expiresAt (borda) e devolve o comando', () => {
      const now = new Date(command.expiresAt);

      const result = parsePayload('commands', TERMINAL, json(command), { now });

      expect(result).toMatchObject({ ok: false, code: 'expired', command: { commandId: UUID_CMD } });
    });

    it('rejeita comando vencido ha mais tempo', () => {
      const now = new Date(NOW.getTime() + 60_000);

      expect(parsePayload('commands', TERMINAL, json(command), { now })).toMatchObject({
        ok: false,
        code: 'expired',
      });
    });

    it('nao confere expiracao quando `now` nao e informado', () => {
      const velho = { ...command, expiresAt: '2020-01-01T00:00:00.000Z' };

      expect(parsePayload('commands', TERMINAL, json(velho)).ok).toBe(true);
    });

    it('so confere expiracao em comandos (qr vencido continua valido para o parser)', () => {
      const qr = { ...envelope(UUID_B), token: 'abc', expiresAt: '2020-01-01T00:00:00.000Z' };

      expect(parsePayload('qr', TERMINAL, json(qr), { now: NOW }).ok).toBe(true);
    });
  });
});
