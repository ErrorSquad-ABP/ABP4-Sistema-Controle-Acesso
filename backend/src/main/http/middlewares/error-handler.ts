import type { ErrorRequestHandler } from 'express';
import { ZodError, z } from 'zod';
import { DomainError } from '../../../domain/errors/domain-error.js';
import type { Logger } from '../../../shared/logger.js';
import { errorBody } from '../http-error.js';

/** Erro de dominio novo? Registre o `code` aqui; sem registro vira 400. */
const STATUS_BY_DOMAIN_CODE: Record<string, number> = {
  VALIDATION_ERROR: 422,
  NOT_FOUND: 404,
  CONFLICT: 409,
  UNAUTHORIZED: 401,
  FORBIDDEN: 403,
};

/** Erros do body-parser/http-errors trazem `status` e `expose`. */
interface ClientHttpError {
  status: number;
  expose?: boolean;
  type?: string;
  message: string;
}

function isClientHttpError(err: unknown): err is ClientHttpError {
  const status = (err as { status?: unknown } | null)?.status;
  return typeof status === 'number' && status >= 400 && status < 500;
}

export function errorHandler(logger: Logger): ErrorRequestHandler {
  // Express identifica error handler pela aridade 4: `_next` precisa ficar.
  return (err: unknown, req, res, _next) => {
    if (err instanceof DomainError) {
      const status = STATUS_BY_DOMAIN_CODE[err.code] ?? 400;
      res.status(status).json(errorBody(err.code, err.message, err.details));
      return;
    }

    if (err instanceof ZodError) {
      res
        .status(400)
        .json(errorBody('INVALID_REQUEST', 'Requisicao invalida', z.flattenError(err).fieldErrors));
      return;
    }

    if (isClientHttpError(err)) {
      const code = err.type === 'entity.parse.failed' ? 'INVALID_JSON' : 'BAD_REQUEST';
      const message = err.type === 'entity.parse.failed' ? 'JSON malformado' : err.message;
      res.status(err.status).json(errorBody(code, err.expose === false ? 'Requisicao invalida' : message));
      return;
    }

    // Erro inesperado: detalhe so no log, nunca na resposta (RNF02).
    logger.error('erro nao tratado', {
      method: req.method,
      path: req.originalUrl,
      err: err instanceof Error ? { name: err.name, message: err.message, stack: err.stack } : err,
    });
    res.status(500).json(errorBody('INTERNAL_ERROR', 'Erro interno do servidor'));
  };
}
