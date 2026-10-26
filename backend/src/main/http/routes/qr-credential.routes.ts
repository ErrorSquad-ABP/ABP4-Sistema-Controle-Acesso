import { Router } from 'express';
import { z } from 'zod';
import type { ValidateQrCredentialUseCase } from '../../../application/terminal/qr-credential.use-cases.js';

const requestSchema = z.object({ token: z.string().min(1).max(2048), terminalId: z.string().min(1).max(100) });

export function qrCredentialRoutes(validate: ValidateQrCredentialUseCase): Router {
  const router = Router();
  router.post('/qr-credentials/validate', (req, res) => {
    const input = requestSchema.parse(req.body ?? {});
    const result = validate.execute(input.token, input.terminalId);
    res.status(200).json(result.valid ? { valid: true } : { valid: false });
  });
  return router;
}
