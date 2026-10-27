import { Router } from 'express';
import type { Container } from '../../composition-root.js';
import { AccessEvent, AccessEventPage, AccessResult, ListAccessEventsQuery, ListMyAccessEventsQuery, QrAccessRequest } from '../contract/schemas/access-events.schemas.js';

export function accessEventsRoutes(access: NonNullable<Container['useCases']['access']>): Router {
  const router = Router();
  // Resposta explicita impede vazar campos internos (hashes, credencial e flags de usuario).
  const event = (value: unknown) => AccessEvent.parse(value);
  router.post('/access-events/qr', async (req, res) => {
    const user = await access.authenticate.execute(req.headers.authorization);
    const input = QrAccessRequest.parse(req.body);
    const result = await access.requestQr.execute({ ...input, userId: user.id });
    res.status(200).json(AccessResult.parse({ ...result, event: event(result.event) }));
  });
  router.get('/access-events', async (req, res) => {
    await access.authenticate.execute(req.headers.authorization, true);
    const result = await access.list.execute(ListAccessEventsQuery.parse(req.query));
    res.status(200).json(AccessEventPage.parse({ ...result, items: result.items.map(event) }));
  });
  router.get('/me/access-events', async (req, res) => {
    const user = await access.authenticate.execute(req.headers.authorization);
    const result = await access.list.execute({ ...ListMyAccessEventsQuery.parse(req.query), userId: user.id });
    res.status(200).json(AccessEventPage.parse({ ...result, items: result.items.map(event) }));
  });
  return router;
}
