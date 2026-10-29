import { Router } from 'express';
import { NotFoundError, ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import { Authorization, AuthorizationPage, CancelAuthorizationRequest, CreateAuthorizationRequest, ListAuthorizationsQuery, ListMyAuthorizationsQuery } from '../contract/schemas/authorizations.schemas.js';
import { IdParams } from '../contract/schemas/common.schemas.js';
import { requireAdmin, requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function authorizationsRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();
  const admin = [rateLimit, requireAuth(container), requireAdmin];

  router.get('/me/authorizations', rateLimit, requireAuth(container), async (req, res) => {
    const query = ListMyAuthorizationsQuery.parse(req.query);
    const useCase = container.useCases.listMyAuthorizations;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');

    res.status(200).json(AuthorizationPage.parse(await useCase.execute(res.locals.user.id, query)));
  });

  router.get('/authorizations', ...admin, async (req, res) => {
    const query = ListAuthorizationsQuery.parse(req.query);
    const useCase = container.useCases.listAuthorizations;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');
    res.status(200).json(AuthorizationPage.parse(await useCase.execute({
      ...query,
      from: query.from ? new Date(query.from) : undefined,
      to: query.to ? new Date(query.to) : undefined,
    })));
  });

  router.post('/authorizations', ...admin, async (req, res) => {
    const body = CreateAuthorizationRequest.parse(req.body ?? {});
    const useCase = container.useCases.createAuthorization;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');
    res.status(201).json(Authorization.parse(await useCase.execute(body, res.locals.user.id)));
  });

  router.get('/authorizations/:id', rateLimit, requireAuth(container), async (req, res) => {
    const { id } = IdParams.parse(req.params);
    const useCase = container.useCases.getAuthorization;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');
    const authorization = await useCase.execute(id);
    if (res.locals.user.role !== 'ADMIN' && authorization.user.id !== res.locals.user.id) {
      throw new NotFoundError('Autorizacao nao encontrada');
    }
    res.status(200).json(Authorization.parse(authorization));
  });

  router.post('/authorizations/:id/cancel', ...admin, async (req, res) => {
    const { id } = IdParams.parse(req.params);
    const body = CancelAuthorizationRequest.parse(req.body ?? {});
    const useCase = container.useCases.cancelAuthorization;
    if (!useCase) throw new ServiceUnavailableError('Autorizacoes indisponiveis sem banco configurado');
    res.status(200).json(Authorization.parse(await useCase.execute(id, body.reason)));
  });

  return router;
}
