import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';

const SECRET = 'a'.repeat(64);
const WEB = 'http://localhost:5000';
const DEMO = 'https://demo.exemplo.app';
const LOGIN = '/api/v1/auth/login';

function appWith(corsAllowedOrigins?: string) {
  const env = loadEnv({
    NODE_ENV: 'test',
    LOG_LEVEL: 'silent',
    QR_TOKEN_SECRET: SECRET,
    ...(corsAllowedOrigins === undefined ? {} : { CORS_ALLOWED_ORIGINS: corsAllowedOrigins }),
  });
  return createApp(buildContainer(env));
}

const withCors = () => appWith(`${WEB},${DEMO}`);

function preflight(app: ReturnType<typeof appWith>, origin: string) {
  return request(app)
    .options(LOGIN)
    .set('Origin', origin)
    .set('Access-Control-Request-Method', 'POST')
    .set('Access-Control-Request-Headers', 'authorization,content-type');
}

describe('DT-08: preflight de /auth/login', () => {
  it('origem permitida: 204 com origem, metodos, cabecalhos e cache do preflight', async () => {
    const res = await preflight(withCors(), WEB);

    expect(res.status).toBe(204);
    expect(res.text).toBe('');
    expect(res.headers['access-control-allow-origin']).toBe(WEB);
    expect(res.headers['access-control-allow-methods']).toBe('GET, POST, PATCH, DELETE, OPTIONS');
    expect(res.headers['access-control-allow-headers']).toBe('Authorization, Content-Type');
    expect(res.headers['access-control-max-age']).toBe('600');
    expect(res.headers.vary).toContain('Origin');
  });

  it('devolve somente a origem que chamou, nunca a lista nem curinga', async () => {
    const res = await preflight(withCors(), DEMO);

    expect(res.headers['access-control-allow-origin']).toBe(DEMO);
    expect(res.headers['access-control-allow-origin']).not.toContain(WEB);
    expect(res.headers['access-control-allow-origin']).not.toBe('*');
  });

  it('nao envia credenciais: a autenticacao e Bearer', async () => {
    const res = await preflight(withCors(), WEB);

    expect(res.headers['access-control-allow-credentials']).toBeUndefined();
  });

  it.each([
    ['origem fora da lista', 'https://intruso.exemplo.com'],
    ['mesmo host com outra porta', 'http://localhost:5001'],
    ['mesmo host com outro esquema', 'https://localhost:5000'],
    ['subdominio da origem permitida', 'https://x.demo.exemplo.app'],
    ['origem opaca', 'null'],
  ])('%s: 204 sem nenhum cabecalho de permissao', async (_caso, origin) => {
    const res = await preflight(withCors(), origin);

    expect(res.status).toBe(204);
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
    expect(res.headers['access-control-allow-methods']).toBeUndefined();
    expect(res.headers['access-control-allow-headers']).toBeUndefined();
    expect(res.headers.vary).toContain('Origin');
  });

  it('o preflight nao consome o limite de login', async () => {
    const app = withCors();
    for (let i = 0; i < 15; i += 1) await preflight(app, WEB);

    const res = await request(app).post(LOGIN).send({});

    expect(res.status).toBe(400);
  });

  it('sem allowlist (padrao) o CORS fica desligado: nenhum cabecalho de permissao', async () => {
    const res = await preflight(appWith(), WEB);

    expect(res.headers['access-control-allow-origin']).toBeUndefined();
    expect(res.headers['access-control-allow-methods']).toBeUndefined();
    expect(res.status).not.toBe(204);
  });
});

describe('DT-08: respostas reais', () => {
  it('origem permitida recebe o cabecalho na resposta normal e no erro de validacao', async () => {
    const app = withCors();

    const ok = await request(app).get('/health').set('Origin', WEB);
    const erro = await request(app).post(LOGIN).set('Origin', WEB).send({});

    expect(ok.headers['access-control-allow-origin']).toBe(WEB);
    expect(erro.status).toBe(400);
    expect(erro.headers['access-control-allow-origin']).toBe(WEB);
    expect(erro.headers.vary).toContain('Origin');
  });

  it('o 429 do login tambem leva o cabecalho, para o app web conseguir ler o erro', async () => {
    const app = withCors();
    let ultimo = await request(app).post(LOGIN).set('Origin', WEB).send({});
    for (let i = 0; i < 10; i += 1) ultimo = await request(app).post(LOGIN).set('Origin', WEB).send({});

    expect(ultimo.status).toBe(429);
    expect(ultimo.headers['access-control-allow-origin']).toBe(WEB);
  });

  it('origem fora da lista: a requisicao responde normal, sem permissao de leitura', async () => {
    const res = await request(withCors()).get('/health').set('Origin', 'https://intruso.exemplo.com');

    expect(res.status).toBe(200);
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
    expect(res.headers.vary).toContain('Origin');
  });

  it('sem Origin (app nativo, curl) nada muda', async () => {
    const res = await request(withCors()).get('/health');

    expect(res.status).toBe(200);
    expect(res.headers['access-control-allow-origin']).toBeUndefined();
    expect(res.headers.vary).toBeUndefined();
  });

  it('OPTIONS sem Access-Control-Request-Method nao e preflight e segue o Express', async () => {
    const res = await request(withCors()).options(LOGIN).set('Origin', WEB);

    expect(res.status).toBe(200);
    expect(res.headers['access-control-allow-origin']).toBe(WEB);
    expect(res.headers['access-control-allow-methods']).toBeUndefined();
  });
});
