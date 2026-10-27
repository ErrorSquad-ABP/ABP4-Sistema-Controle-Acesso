import { createHash } from 'node:crypto';
import type { TokenHasher } from '../../domain/ports/token-hasher.js';

export class Sha256TokenHasher implements TokenHasher {
  hash(value: string): string { return createHash('sha256').update(value).digest('hex'); }
}
