import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import { AuthorizationPage, ListMyAuthorizationsQuery } from '../contract/schemas/authorizations.schemas.js';
import { requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function authorizationsRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();

  router.get('/me/authorizations', rateLimit, requireAuth(container), async (req, res) => {
    const query = ListMyAuthorizationsQuery.parse(req.query);
    const useCase = container.useCases.listMyAuthorizations;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');

    res.status(200).json(AuthorizationPage.parse(await useCase.execute(res.locals.user.id, query)));
  });

  return router;
}
