import { rateLimit } from 'express-rate-limit';
import type { RequestHandler } from 'express';
import { errorBody } from '../http-error.js';

interface RateLimitOptions {
  windowMs: number;
  limit: number;
  message: string;
}

function tooManyRequests(message: string): RequestHandler {
  return (_req, res) => {
    res.status(429).json(errorBody('TOO_MANY_REQUESTS', message));
  };
}

/**
 * Limite em memoria, por instancia: segura forca bruta casual no login sem
 * depender de store externo. Em serverless cada instancia tem seu contador;
 * store compartilhado fica para a US-33.
 */
export function createRateLimit({ windowMs, limit, message }: RateLimitOptions): RequestHandler {
  return rateLimit({
    windowMs,
    limit,
    standardHeaders: 'draft-8',
    legacyHeaders: false,
    handler: tooManyRequests(message),
  });
}

export function createLoginRateLimit(): RequestHandler {
  return createRateLimit({
    windowMs: 15 * 60_000,
    limit: 10,
    message: 'Muitas tentativas de login; tente novamente mais tarde',
  });
}

export function createAuthenticatedRateLimit(): RequestHandler {
  return createRateLimit({
    windowMs: 60_000,
    limit: 120,
    message: 'Muitas requisicoes; tente novamente em instantes',
  });
}
