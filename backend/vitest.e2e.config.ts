import { defineConfig } from 'vitest/config';

export default defineConfig({ test: {
  include: ['tests/e2e/**/*.e2e.ts'], environment: 'node',
  fileParallelism: false, testTimeout: 30_000,
} });
