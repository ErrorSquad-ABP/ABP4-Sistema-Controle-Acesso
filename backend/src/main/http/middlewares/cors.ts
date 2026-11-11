import type { RequestHandler } from 'express';

const ALLOWED_METHODS = 'GET, POST, PATCH, DELETE, OPTIONS';
/** `Authorization` precisa ser citado: o curinga `*` nao o cobre. */
const ALLOWED_HEADERS = 'Authorization, Content-Type';
const PREFLIGHT_MAX_AGE_SECONDS = '600';

/**
 * CORS por allowlist exata (DT-08). Nao ha curinga, regex nem reflexo de origem
 * qualquer: so a origem que esta na lista volta em `Access-Control-Allow-Origin`.
 * Sem credenciais: a autenticacao e Bearer, nao cookie.
 *
 * CORS so diz ao navegador o que o app web pode ler. Nao autentica nem bloqueia
 * a requisicao no servidor; a protecao real continua sendo o JWT.
 */
export function createCors(allowedOrigins: readonly string[]): RequestHandler {
  const allowed = new Set(allowedOrigins);

  return (req, res, next) => {
    const origin = req.headers.origin;
    // Lista vazia = CORS desligado (comportamento anterior); sem Origin = nao e navegador entre origens.
    if (allowed.size === 0 || origin === undefined) {
      next();
      return;
    }

    // A resposta muda conforme a origem: caches nao podem reaproveitar a de outra.
    res.vary('Origin');
    const permitted = allowed.has(origin);
    // Cabecalho em toda resposta (4xx, 429, 5xx): o navegador so deixa o app ler o erro com ele.
    if (permitted) res.setHeader('Access-Control-Allow-Origin', origin);

    const isPreflight =
      req.method === 'OPTIONS' && typeof req.headers['access-control-request-method'] === 'string';
    if (!isPreflight) {
      next();
      return;
    }

    // Respondido aqui, antes dos rate limits e das rotas.
    if (permitted) {
      res.setHeader('Access-Control-Allow-Methods', ALLOWED_METHODS);
      res.setHeader('Access-Control-Allow-Headers', ALLOWED_HEADERS);
      res.setHeader('Access-Control-Max-Age', PREFLIGHT_MAX_AGE_SECONDS);
    }
    res.status(204).end();
  };
}
