import express, { type Express, type Router } from 'express';
import type { Container } from '../composition-root.js';
import { errorHandler } from './middlewares/error-handler.js';
import { notFound } from './middlewares/not-found.js';
import { healthRoutes } from './routes/health.routes.js';

export interface CreateAppOptions {
  /** Rotas extras montadas antes do 404 (usado nos testes de integracao). */
  extraRoutes?: Router[];
}

/** Monta o app Express sem `listen` — reaproveitado por server.ts, testes e (US-13) Vercel. */
export function createApp(container: Container, options: CreateAppOptions = {}): Express {
  const app = express();
  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));

  app.use(healthRoutes(container.useCases.checkHealth));
  for (const router of options.extraRoutes ?? []) app.use(router);

  app.use(notFound);
  app.use(errorHandler(container.logger));
  return app;
}
