import { Router } from 'express';
import { ServiceUnavailableError } from '../../../domain/errors/domain-error.js';
import type { Container } from '../../composition-root.js';
import {
  ValidateQrCredentialRequest,
  ValidateQrCredentialResponse,
} from '../contract/schemas/credentials.schemas.js';
import { requireAuth } from '../middlewares/auth.js';
import { createAuthenticatedRateLimit } from '../middlewares/rate-limit.js';

export function credentialsRoutes(container: Container): Router {
  const router = Router();
  const rateLimit = createAuthenticatedRateLimit();

  router.post('/credentials/qr/validate', rateLimit, requireAuth(container), async (req, res) => {
    const body = ValidateQrCredentialRequest.parse(req.body);
    let terminalId = body.terminalId;
    if (!terminalId) {
      const access = container.repositories.access;
      if (!access) throw new ServiceUnavailableError('Validacao do QR compacto indisponivel sem banco configurado');
      const resolved = await access.findTerminalIdByQrCode(body.terminalCode!);
      if (!resolved) {
        // Codigo nao provisionado nao e decisao de acesso: responde sem revelar qual terminal existiria.
        res.status(200).json(ValidateQrCredentialResponse.parse({ valid: false }));
        return;
      }
      terminalId = resolved;
    }
    const result = container.useCases.validateQrCredential.execute(body.qrToken, terminalId, body.terminalCode);
    const response = result.valid
      ? {
          valid: true as const,
          terminalId: result.claims.terminalId,
          expiresAt: new Date(result.claims.expiresAt).toISOString(),
        }
      : { valid: false as const };
    res.status(200).json(ValidateQrCredentialResponse.parse(response));
  });

  return router;
}
