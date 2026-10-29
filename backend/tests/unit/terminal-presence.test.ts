import { describe, expect, it } from 'vitest';
import { PRESENCE_TTL_MS, TerminalPresence } from '../../src/main/mqtt/terminal-presence.js';
import { FixedClock, NOW } from '../support/terminal-fakes.js';

function setup() {
  const clock = new FixedClock(NOW);
  const advance = (ms: number) => {
    clock.date = new Date(clock.date.getTime() + ms);
  };
  return { presence: new TerminalPresence(clock), advance };
}

describe('DT-13: presenca dos terminais para o relay', () => {
  it('sem nenhum sinal o relay fica parado', () => {
    expect(setup().presence.anyOnline()).toBe(false);
  });

  it('online ate o LWT de offline', () => {
    const { presence } = setup();
    presence.update('terminal-01', true);
    expect(presence.anyOnline()).toBe(true);

    presence.update('terminal-01', false);
    expect(presence.anyOnline()).toBe(false);
  });

  it('heartbeat a cada 30 s mantem o terminal presente', () => {
    const { presence, advance } = setup();
    presence.update('terminal-01', true);
    for (let i = 0; i < 5; i += 1) {
      advance(30_000);
      presence.update('terminal-01', true);
      expect(presence.anyOnline()).toBe(true);
    }
  });

  it('sem sinal pelo prazo conta como offline, mesmo sem LWT', () => {
    const { presence, advance } = setup();
    presence.update('terminal-01', true);
    advance(PRESENCE_TTL_MS - 1);
    expect(presence.anyOnline()).toBe(true);
    advance(1);
    expect(presence.anyOnline()).toBe(false);
  });

  it('basta um terminal presente', () => {
    const { presence, advance } = setup();
    presence.update('terminal-01', true);
    advance(60_000);
    presence.update('terminal-02', true);
    advance(60_000);
    expect(presence.anyOnline()).toBe(true);
    presence.update('terminal-02', false);
    expect(presence.anyOnline()).toBe(false);
  });
});
