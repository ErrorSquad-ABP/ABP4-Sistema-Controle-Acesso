import { Router } from 'express';
import type { CheckHealthUseCase } from '../../../application/health/check-health.use-case.js';

/** Controller fino: traduz HTTP <-> caso de uso, sem regra de negocio. */
export function healthRoutes(checkHealth: CheckHealthUseCase): Router {
  const router = Router();
  router.get('/health', (_req, res) => {
    res.status(200).json(checkHealth.execute());
  });
  return router;
}
