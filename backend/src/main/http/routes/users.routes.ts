import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import { IdParams } from '../contract/schemas/common.schemas.js';
import { CreateUserRequest, ListUsersQuery, UpdateUserRequest, User, UserPage } from '../contract/schemas/users.schemas.js';
import { requireAdmin, requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function usersRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();
  const auth = [rateLimit, requireAuth(container), requireAdmin];

  router.get('/users', ...auth, async (req, res) => {
    const query = ListUsersQuery.parse(req.query);
    const useCase = container.useCases.listUsers;
    if (!useCase) throw new ServiceUnavailableError('Cadastro de usuarios indisponivel sem banco configurado');

    res.status(200).json(UserPage.parse(await useCase.execute(query)));
  });

  router.post('/users', ...auth, async (req, res) => {
    const body = CreateUserRequest.parse(req.body ?? {});
    const useCase = container.useCases.createUser;
    if (!useCase) throw new ServiceUnavailableError('Cadastro de usuarios indisponivel sem banco configurado');

    res.status(201).json(User.parse(await useCase.execute(body)));
  });

  router.get('/users/:id', ...auth, async (req, res) => {
    const { id } = IdParams.parse(req.params);
    const useCase = container.useCases.getUser;
    if (!useCase) throw new ServiceUnavailableError('Cadastro de usuarios indisponivel sem banco configurado');

    res.status(200).json(User.parse(await useCase.execute(id)));
  });

  router.patch('/users/:id', ...auth, async (req, res) => {
    const { id } = IdParams.parse(req.params);
    const body = UpdateUserRequest.parse(req.body ?? {});
    const useCase = container.useCases.updateUser;
    if (!useCase) throw new ServiceUnavailableError('Cadastro de usuarios indisponivel sem banco configurado');

    res.status(200).json(User.parse(await useCase.execute(id, body)));
  });

  router.delete('/users/:id', ...auth, async (req, res) => {
    const { id } = IdParams.parse(req.params);
    const useCase = container.useCases.deleteUser;
    if (!useCase) throw new ServiceUnavailableError('Cadastro de usuarios indisponivel sem banco configurado');

    await useCase.execute(id);
    res.status(204).end();
  });

  return router;
}
