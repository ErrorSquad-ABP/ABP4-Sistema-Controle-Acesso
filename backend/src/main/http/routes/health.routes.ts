import { Router } from 'express';
import type { CheckHealthUseCase } from '../../../application/health/check-health.use-case.js';

/** Controller fino: traduz HTTP <-> caso de uso, sem regra de negocio. */
export function healthRoutes(checkHealth: CheckHealthUseCase): Router {
  const router = Router();
  router.get('/health', async (_req, res) => {
    const health = await checkHealth.execute();
    res.status(health.status === 'ok' ? 200 : 503).json(health);
  });
  return router;
}
