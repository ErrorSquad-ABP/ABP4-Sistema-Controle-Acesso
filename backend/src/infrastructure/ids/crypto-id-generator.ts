import { randomBytes, randomUUID } from 'node:crypto';
import type { IdGenerator } from '../../domain/ports/id-generator.js';

export class CryptoIdGenerator implements IdGenerator {
  uuid(): string {
    return randomUUID();
  }

  token(): string {
    return randomBytes(32).toString('hex');
  }
}
