import { Router } from 'express';
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

  router.post('/credentials/qr/validate', rateLimit, requireAuth(container), (req, res) => {
    const body = ValidateQrCredentialRequest.parse(req.body);
    const result = container.useCases.validateQrCredential.execute(body.qrToken, body.terminalId);
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
