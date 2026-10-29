import { describe, expect, it } from 'vitest';
import { isWithinRelayWindow, type RelayWindow } from '../../src/domain/terminal/relay-window.js';

const janela: RelayWindow = {
  enabled: true,
  start: '18:45',
  end: '23:05',
  timeZone: 'America/Sao_Paulo',
};

/** 21:00 BRT = 00:00 UTC do dia seguinte. */
const emBrt = (hora: number, minuto = 0, dia = 29): Date =>
  new Date(Date.UTC(2026, 9, dia, hora + 3, minuto));

describe('janela do relay (DT-21)', () => {
  it('libera quando a janela esta desligada', () => {
    expect(isWithinRelayWindow(emBrt(3), { ...janela, enabled: false })).toBe(true);
  });

  it('fecha antes do inicio', () => {
    expect(isWithinRelayWindow(emBrt(18, 44), janela)).toBe(false);
  });

  it('abre exatamente no inicio', () => {
    expect(isWithinRelayWindow(emBrt(18, 45), janela)).toBe(true);
  });

  it('permanece aberta no meio', () => {
    expect(isWithinRelayWindow(emBrt(20, 30), janela)).toBe(true);
  });

  it('fecha exatamente no fim', () => {
    expect(isWithinRelayWindow(emBrt(23, 5), janela)).toBe(false);
  });

  it('continua fechada depois do fim', () => {
    expect(isWithinRelayWindow(emBrt(23, 6), janela)).toBe(false);
  });

  it('usa o fuso configurado, nao o do processo', () => {
    // 02:00 UTC de 30/10 = 23:00 BRT de 29/10 (dentro). Em UTC estaria fora.
    const agora = new Date(Date.UTC(2026, 9, 30, 2, 0));
    expect(isWithinRelayWindow(agora, janela)).toBe(true);
    expect(isWithinRelayWindow(agora, { ...janela, timeZone: 'UTC' })).toBe(false);
  });

  it('aceita janela que atravessa a meia-noite', () => {
    const noturna: RelayWindow = { ...janela, start: '22:00', end: '02:00' };
    expect(isWithinRelayWindow(emBrt(23), noturna)).toBe(true);
    expect(isWithinRelayWindow(emBrt(1), noturna)).toBe(true);
    expect(isWithinRelayWindow(emBrt(12), noturna)).toBe(false);
  });
});
