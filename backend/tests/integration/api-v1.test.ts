import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { API_V1_PREFIX, buildOpenApiDocument } from '../../src/main/http/contract/openapi.js';
import { type Operation, operations } from '../../src/main/http/contract/operations.js';
import { createApp } from '../../src/main/http/app.js';

const env = loadEnv({ NODE_ENV: 'test', LOG_LEVEL: 'silent', QR_TOKEN_SECRET: 'a'.repeat(64) });
const app = createApp(buildContainer(env));

/** Rotas ja implementadas saem do loop de stub; o teste real de cada uma vive no seu arquivo. */
const IMPLEMENTED = new Set([
  'login',
  'getCurrentUser',
  'listUsers',
  'createUser',
  'getUser',
  'updateUser',
  'deleteUser',
  'listMyAuthorizations',
  'listAuthorizations',
  'createAuthorization',
  'getAuthorization',
  'cancelAuthorization',
  'listMyAccessEvents',
  'listAccessEvents',
  'validateQrCredential',
  'requestQrAccess',
]);

function urlFor(op: Operation, params: Record<string, string> = op.example.params ?? {}): string {
  const path = op.path.replace(/:(\w+)/g, (_match, name: string) => params[name] ?? `:${name}`);
  return `${API_V1_PREFIX}${path}`;
}

function send(op: Operation, url: string, query?: Record<string, string>, body?: unknown) {
  const req = request(app)[op.method](url).query(query ?? {});
  return body === undefined ? req : req.send(body as object);
}

describe('rotas stub do contrato v1', () => {
  const pending = operations.filter((op) => !IMPLEMENTED.has(op.operationId));

  it.each(pending.map((op) => [`${op.method.toUpperCase()} ${op.path}`, op] as const))(
    '%s valida a entrada e responde 501 NOT_IMPLEMENTED',
    async (_name, op) => {
      const res = await send(op, urlFor(op), op.example.query, op.example.body);

      expect(res.status).toBe(501);
      expect(res.body.error.code).toBe('NOT_IMPLEMENTED');
      expect(res.body.error.message).toContain(op.story);
    },
  );

  it('body invalido -> 400 INVALID_REQUEST com o campo', async () => {
    const res = await request(app)
      .post(`${API_V1_PREFIX}/auth/login`)
      .send({ email: 'nao-e-email', password: 'x' });

    expect(res.status).toBe(400);
    expect(res.body.error.code).toBe('INVALID_REQUEST');
    expect(res.body.error.details).toHaveProperty('email');
  });

  it('validacao QR deixou de ser stub e exige sessao', async () => {
    const res = await request(app)
      .post(`${API_V1_PREFIX}/credentials/qr/validate`)
      .send({ qrToken: 'token.assinado', terminalId: 'aurora-recepcao' });

    // Sem banco neste app de teste, a autenticacao falha antes do handler (nunca 501).
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
  });

  it('pedido de acesso QR deixou de ser stub e exige sessao', async () => {
    const res = await request(app)
      .post(`${API_V1_PREFIX}/access-events/qr`)
      .send({ qrToken: 'token', terminalId: 'aurora-recepcao', position: { latitude: 0, longitude: 0 } });

    // Sem banco neste app de teste, a autenticacao falha antes do handler (nunca 501).
    expect(res.status).toBe(503);
    expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
  });

  it('usuarios e minhas autorizacoes deixaram de ser stub e exigem sessao', async () => {
    const users = await request(app).get(`${API_V1_PREFIX}/users`);
    const mine = await request(app).get(`${API_V1_PREFIX}/me/authorizations`);

    for (const res of [users, mine]) {
      expect(res.status).toBe(503);
      expect(res.body.error.code).toBe('SERVICE_UNAVAILABLE');
    }
  });

  it('nao publica uma rota antiga de validacao sem autenticacao', async () => {
    const res = await request(app).post('/qr-credentials/validate').send({ token: 'x', terminalId: 'terminal-01' });
    expect(res.status).toBe(404);
  });
});

describe('publicacao do contrato', () => {
  it('GET /openapi.json devolve o documento gerado do codigo', async () => {
    const res = await request(app).get('/openapi.json');

    expect(res.status).toBe(200);
    expect(res.body).toEqual(JSON.parse(JSON.stringify(buildOpenApiDocument())));
  });

  it('GET /docs serve o Swagger UI apontando para o openapi.json', async () => {
    const res = await request(app).get('/docs');

    expect(res.status).toBe(200);
    expect(res.headers['content-type']).toContain('text/html');
    expect(res.text).toContain('swagger-ui-dist@');
    expect(res.text).toContain("url: './openapi.json'");
  });
});
