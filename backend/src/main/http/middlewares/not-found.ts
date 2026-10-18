import type { RequestHandler } from 'express';
import { errorBody } from '../http-error.js';

export const notFound: RequestHandler = (req, res) => {
  res.status(404).json(errorBody('ROUTE_NOT_FOUND', `Rota ${req.method} ${req.path} nao encontrada`));
};
