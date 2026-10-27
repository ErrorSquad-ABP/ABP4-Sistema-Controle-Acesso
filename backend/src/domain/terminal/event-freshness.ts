export const ACCESS_EVENT_MAX_AGE_MS = 30_000;
export const ACCESS_EVENT_FUTURE_SKEW_MS = 5_000;

export function isFreshAccessEvent(timestamp: string, now: Date): boolean {
  const age = now.getTime() - Date.parse(timestamp);
  return Number.isFinite(age) && age < ACCESS_EVENT_MAX_AGE_MS && age >= -ACCESS_EVENT_FUTURE_SKEW_MS;
}
