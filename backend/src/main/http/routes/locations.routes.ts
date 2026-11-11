import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import { PaginationQuery } from '../contract/schemas/common.schemas.js';
import { CreateLocationRequest, Location, LocationPage } from '../contract/schemas/locations.schemas.js';
import { requireAdmin, requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function locationsRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();

  router.get('/locations', rateLimit, requireAuth(container), async (req, res) => {
    const query = PaginationQuery.parse(req.query);
    const useCase = container.useCases.listLocations;
    if (!useCase) throw new ServiceUnavailableError('Locais indisponiveis sem banco configurado');

    res.status(200).json(LocationPage.parse(await useCase.execute(query)));
  });

  router.post('/locations', rateLimit, requireAuth(container), requireAdmin, async (req, res) => {
    const body = CreateLocationRequest.parse(req.body ?? {});
    const useCase = container.useCases.createLocation;
    if (!useCase) throw new ServiceUnavailableError('Locais indisponiveis sem banco configurado');

    res.status(201).json(Location.parse(await useCase.execute(body)));
  });

  return router;
}
