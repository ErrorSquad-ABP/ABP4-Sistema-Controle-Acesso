import { describe, expect, it, vi } from 'vitest';
import { PublishQrCodeUseCase } from '../../src/application/terminal/publish-qr-code.use-case.js';
import type { AccessRepository } from '../../src/domain/ports/access-repository.js';
import { FixedClock, NOW, RecordingBus, SequentialIds, TERMINAL } from '../support/terminal-fakes.js';

describe('QR real exige terminal cadastrado e ativo', () => {
  it('nao publica QR se o cadastro nao permite persistir seu vinculo', async () => {
    const repository: AccessRepository = { transaction: vi.fn(), findUser: vi.fn(), list: vi.fn(), saveQrToken: vi.fn().mockResolvedValue(false) };
    const bus = new RecordingBus();
    const useCase = new PublishQrCodeUseCase(bus, new FixedClock(NOW), new SequentialIds(), {
      repository, hasher: { hash: () => 'hash-sem-token-original' },
    });
    await expect(useCase.execute({ terminalId: TERMINAL })).rejects.toThrow('Terminal');
    expect(bus.published).toHaveLength(0);
  });
});
