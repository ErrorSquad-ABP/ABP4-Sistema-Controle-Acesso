import { setTimeout as delay } from 'node:timers/promises';

/**
 * Roda `work` com amostras em segundo plano. O laco para antes de `work`
 * resolver ou rejeitar: se a preparacao falhar, nenhum timer fica pendente.
 */
export async function withPeakSampling<T>(
  collect: () => Promise<void>,
  work: () => Promise<T>,
  intervalMs = 20,
): Promise<T> {
  let sampling = true;
  const sampler = (async () => {
    while (sampling) {
      try {
        await collect();
      } catch {
        // Amostra perdida (banco ocupado) nao zera o pico ja acumulado.
      }
      if (sampling) await delay(intervalMs);
    }
  })();

  try {
    return await work();
  } finally {
    sampling = false;
    await sampler;
  }
}
