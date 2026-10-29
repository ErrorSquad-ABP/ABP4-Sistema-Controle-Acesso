/**
 * Janela de operacao do relay da outbox (DT-21). Fora dela o worker nao consulta
 * o banco: e o polling que mantem o Neon acordado 24/7 e estoura o free tier.
 * A janela e avaliada no fuso configurado (o do processo nao serve: o worker roda
 * em UTC no Render). Aceita janela que atravessa a meia-noite.
 */
export interface RelayWindow {
  readonly enabled: boolean;
  /** `HH:mm` no fuso da janela. */
  readonly start: string;
  /** `HH:mm`; o minuto final e exclusivo. */
  readonly end: string;
  readonly timeZone: string;
}

const MINUTES_IN_DAY = 24 * 60;

function minutesOfTime(value: string): number {
  const [hours, minutes] = value.split(':').map(Number);
  return (hours ?? 0) * 60 + (minutes ?? 0);
}

function minutesOfDay(now: Date, timeZone: string): number {
  const parts = new Intl.DateTimeFormat('en-GB', {
    timeZone,
    hour: '2-digit',
    minute: '2-digit',
    hourCycle: 'h23',
  }).formatToParts(now);
  const value = (type: 'hour' | 'minute'): number =>
    Number(parts.find((part) => part.type === type)?.value ?? '0');
  return (value('hour') % 24) * 60 + value('minute');
}

export function isWithinRelayWindow(now: Date, window: RelayWindow): boolean {
  if (!window.enabled) return true;
  const current = minutesOfDay(now, window.timeZone);
  const start = minutesOfTime(window.start);
  const end = minutesOfTime(window.end);
  if (start === end) return false;
  if (start < end) return current >= start && current < end;
  // Janela que atravessa a meia-noite (ex.: 22:00 -> 02:00).
  return current >= start || current < end;
}

export { MINUTES_IN_DAY };
