import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import {
  AccessEvent,
  AccessEventPage,
  AccessResult,
  ListAccessEventsQuery,
  ListMyAccessEventsQuery,
  QrAccessRequest,
} from '../contract/schemas/access-events.schemas.js';
import { requireAdmin, requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function accessEventsRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();

  router.post('/access-events/qr', rateLimit, requireAuth(container), async (req, res) => {
    const useCase = container.useCases.requestQrAccess;
    if (!useCase) throw new ServiceUnavailableError('Decisao de acesso indisponivel sem banco configurado');

    const input = QrAccessRequest.parse(req.body);
    const result = await useCase.execute({ ...input, userId: res.locals.user.id });
    res.status(200).json(AccessResult.parse({ ...result, event: AccessEvent.parse(result.event) }));
  });

  router.get('/me/access-events', rateLimit, requireAuth(container), async (req, res) => {
    const query = ListMyAccessEventsQuery.parse(req.query);
    const useCase = container.useCases.listMyAccessEvents;
    if (!useCase) throw new ServiceUnavailableError('Historico indisponivel sem banco configurado');

    const result = await useCase.execute(res.locals.user.id, query);
    res.status(200).json(
      AccessEventPage.parse({ ...result, page: query.page, pageSize: query.pageSize }),
    );
  });

  router.get('/access-events', rateLimit, requireAuth(container), requireAdmin, async (req, res) => {
    const query = ListAccessEventsQuery.parse(req.query);
    const useCase = container.useCases.listAccessEvents;
    if (!useCase) throw new ServiceUnavailableError('Historico indisponivel sem banco configurado');

    const result = await useCase.execute(query);
    res.status(200).json(
      AccessEventPage.parse({ ...result, page: query.page, pageSize: query.pageSize }),
    );
  });

  return router;
}
