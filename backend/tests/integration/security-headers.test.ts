import request from 'supertest';
import { describe, expect, it } from 'vitest';
import { buildContainer } from '../../src/main/composition-root.js';
import { loadEnv } from '../../src/main/config/env.js';
import { createApp } from '../../src/main/http/app.js';

const ORIGIN = 'http://localhost:5000';

function appFor(nodeEnv: 'test' | 'production' = 'test') {
  const env = loadEnv({
    NODE_ENV: nodeEnv,
    LOG_LEVEL: 'silent',
    QR_TOKEN_SECRET: 'a'.repeat(64),
    JWT_SECRET: 'test-jwt-secret-that-is-long-enough',
    CORS_ALLOWED_ORIGINS: ORIGIN,
  });
  return createApp(buildContainer(env));
}

function expectCommonHeaders(headers: Record<string, string>) {
  expect(headers['x-content-type-options']).toBe('nosniff');
  expect(headers['x-frame-options']).toBe('DENY');
  expect(headers['referrer-policy']).toBe('no-referrer');
  expect(headers['permissions-policy']).toBe('camera=(), microphone=(), geolocation=()');
  expect(headers['cross-origin-resource-policy']).toBe('same-origin');
  expect(headers['content-security-policy']).toContain("default-src 'none'");
  expect(headers['x-powered-by']).toBeUndefined();
}

describe('security headers', () => {
  it('applies headers to normal responses, errors and 404s', async () => {
    const app = appFor();
    const normal = await request(app).get('/health');
    const malformed = await request(app).post('/api/v1/auth/login').set('Content-Type', 'application/json').send('{');
    const notFound = await request(app).get('/missing');

    expect(normal.status).toBe(200);
    expect(malformed.status).toBe(400);
    expect(notFound.status).toBe(404);
    for (const response of [normal, malformed, notFound]) expectCommonHeaders(response.headers);
    expect(normal.headers['strict-transport-security']).toBeUndefined();
  });

  it('keeps security headers on allowed CORS preflight and applies the API CSP', async () => {
    const response = await request(appFor())
      .options('/api/v1/auth/login')
      .set('Origin', ORIGIN)
      .set('Access-Control-Request-Method', 'POST')
      .set('Access-Control-Request-Headers', 'content-type');

    expect(response.status).toBe(204);
    expect(response.headers['access-control-allow-origin']).toBe(ORIGIN);
    expectCommonHeaders(response.headers);
  });

  it('uses a Swagger-specific CSP and sends HSTS only in production', async () => {
    const developmentDocs = await request(appFor()).get('/docs');
    const productionHealth = await request(appFor('production')).get('/health');
    const productionDocs = await request(appFor('production')).get('/docs');

    expect(developmentDocs.headers['content-security-policy']).toContain('script-src https://cdn.jsdelivr.net');
    expect(developmentDocs.headers['content-security-policy']).toContain("'unsafe-inline'");
    expect(developmentDocs.headers['strict-transport-security']).toBeUndefined();
    expect(productionHealth.headers['strict-transport-security']).toBe('max-age=31536000; includeSubDomains');
    expect(productionDocs.headers['strict-transport-security']).toBe('max-age=31536000; includeSubDomains');
    expect(productionDocs.headers['content-security-policy']).toContain('script-src https://cdn.jsdelivr.net');
  });
});
