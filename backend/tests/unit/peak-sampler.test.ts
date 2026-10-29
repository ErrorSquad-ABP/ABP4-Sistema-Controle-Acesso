import { setTimeout as delay } from 'node:timers/promises';
import { describe, expect, it } from 'vitest';
import { withPeakSampling } from '../support/peak-sampler.js';

describe('withPeakSampling', () => {
  it('encerra o laco quando a preparacao falha', async () => {
    let calls = 0;
    const failure = new Error('preparacao falhou');
    await expect(
      withPeakSampling(
        async () => {
          calls += 1;
        },
        async () => {
          throw failure;
        },
        5,
      ),
    ).rejects.toBe(failure);

    const afterFailure = calls;
    await delay(50);
    expect(calls).toBe(afterFailure);
  });

  it('devolve o resultado do trabalho e para de amostrar', async () => {
    let calls = 0;
    const result = await withPeakSampling(
      async () => {
        calls += 1;
      },
      async () => 'pronto',
      5,
    );

    expect(result).toBe('pronto');
    const afterWork = calls;
    await delay(50);
    expect(calls).toBe(afterWork);
    expect(afterWork).toBeGreaterThan(0);
  });
});
