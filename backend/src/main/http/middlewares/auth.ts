import type { RequestHandler } from 'express';
import { UnauthorizedError, ForbiddenError, ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';

/** Valida o Bearer e recarrega o usuario: desativacao e troca de perfil valem na hora. */
export function requireAuth(container: Container): RequestHandler {
  return async (req, res, next) => {
    try {
      const getCurrentUser = container.useCases.getCurrentUser;
      if (!getCurrentUser) throw new ServiceUnavailableError('Autenticacao indisponivel');

      const [scheme, token] = (req.header('authorization') ?? '').split(' ');
      if (scheme?.toLowerCase() !== 'bearer' || !token) throw new UnauthorizedError('Token ausente');

      const claims = await container.tokens.verify(token);
      res.locals.user = await getCurrentUser.execute(claims.userId);
      next();
    } catch (err) {
      next(err);
    }
  };
}

export const requireAdmin: RequestHandler = (_req, res, next) => {
  if (res.locals.user?.role !== 'ADMIN') return next(new ForbiddenError('Perfil sem permissao'));
  next();
};
