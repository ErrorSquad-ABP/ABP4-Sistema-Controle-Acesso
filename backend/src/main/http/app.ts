import express, { type Express, type Router } from 'express';
import type { Container } from '../composition-root.js';
import { API_V1_PREFIX } from './contract/openapi.js';
import { errorHandler } from './middlewares/error-handler.js';
import { notFound } from './middlewares/not-found.js';
import { apiV1StubRoutes } from './routes/api-v1.routes.js';
import { docsRoutes } from './routes/docs.routes.js';
import { healthRoutes } from './routes/health.routes.js';

export interface CreateAppOptions {
  /** Rotas extras montadas antes do 404 (usado nos testes de integracao). */
  extraRoutes?: Router[];
}

/** Monta o app Express sem `listen` — reaproveitado por server.ts, testes e Vercel. */
export function createApp(container: Container, options: CreateAppOptions = {}): Express {
  return configureApp(express(), container, options);
}

/** Aplica a composição HTTP num app já criado (o entry da Vercel precisa chamar `express()`). */
export function configureApp(
  app: Express,
  container: Container,
  options: CreateAppOptions = {},
): Express {
  app.disable('x-powered-by');
  app.use(express.json({ limit: '100kb' }));

  app.use(healthRoutes(container.useCases.checkHealth));
  app.use(docsRoutes());
  app.use(API_V1_PREFIX, apiV1StubRoutes());
  for (const router of options.extraRoutes ?? []) app.use(router);

  app.use(notFound);
  app.use(errorHandler(container.logger));
  return app;
}
