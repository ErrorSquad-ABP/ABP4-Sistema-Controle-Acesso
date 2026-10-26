import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import { LoginRequest, LoginResponse } from '../contract/schemas/auth.schemas.js';
import { User } from '../contract/schemas/users.schemas.js';
import { requireAuth } from '../middlewares/auth.js';

export function authRoutes(container: Container): Router {
  const router = Router();

  router.post('/auth/login', async (req, res) => {
    // Validacao antes da disponibilidade: entrada invalida e 400 mesmo sem banco.
    const body = LoginRequest.parse(req.body);
    const login = container.useCases.login;
    if (!login) throw new ServiceUnavailableError('Login indisponivel sem banco configurado');
    res.status(200).json(LoginResponse.parse(await login.execute(body)));
  });

  router.get('/auth/me', requireAuth(container), (_req, res) => {
    res.status(200).json(User.parse(res.locals.user));
  });

  return router;
}
