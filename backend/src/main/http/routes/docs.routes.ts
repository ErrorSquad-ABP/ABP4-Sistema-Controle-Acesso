import { Router } from 'express';
import { buildOpenApiDocument } from '../contract/openapi.js';

/** Versao fixa do Swagger UI carregado do CDN (sem dependencia no bundle da API). */
const SWAGGER_UI = 'https://cdn.jsdelivr.net/npm/swagger-ui-dist@5.33.1';

const DOCS_HTML = `<!doctype html>
<html lang="pt-BR">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>API v1 · Controle de Acesso</title>
  <link rel="stylesheet" href="${SWAGGER_UI}/swagger-ui.css">
</head>
<body>
  <div id="swagger-ui"></div>
  <script src="${SWAGGER_UI}/swagger-ui-bundle.js" crossorigin></script>
  <script>
    window.ui = SwaggerUIBundle({ url: './openapi.json', dom_id: '#swagger-ui', deepLinking: true });
  </script>
</body>
</html>`;

/** Publica o contrato: JSON em /openapi.json e Swagger UI em /docs. */
export function docsRoutes(): Router {
  const router = Router();
  const document = buildOpenApiDocument();

  router.get('/openapi.json', (_req, res) => {
    res.status(200).json(document);
  });
  router.get('/docs', (_req, res) => {
    res.status(200).type('html').send(DOCS_HTML);
  });
  return router;
}
