import { Router } from 'express';
import { operations } from '../contract/operations.js';
import { errorBody } from '../http-error.js';

/**
 * Rotas do contrato v1 ainda sem caso de uso: validam a entrada com os
 * schemas Zod do contrato (invalida -> 400) e respondem 501 apontando o card
 * que vai implementa-las. Ao implementar, monte o router real antes deste no
 * app.ts: o Express atende pela primeira rota que casar.
 */
export function apiV1StubRoutes(): Router {
  const router = Router();
  for (const op of operations) {
    router[op.method](op.path, (req, res) => {
      op.params?.parse(req.params);
      op.query?.parse(req.query);
      // Sem Content-Type JSON o Express deixa req.body undefined; trata como objeto vazio.
      op.body?.parse(req.body ?? {});
      res
        .status(501)
        .json(errorBody('NOT_IMPLEMENTED', `${op.operationId} faz parte do contrato v1 e sera implementada na ${op.story}`));
    });
  }
  return router;
}
