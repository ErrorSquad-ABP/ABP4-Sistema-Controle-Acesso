import { readFile } from 'node:fs/promises';
import SwaggerParser from '@apidevtools/swagger-parser';
import type { OpenAPIV3_1 } from 'openapi-types';
import { describe, expect, it } from 'vitest';
import { OPENAPI_YAML_PATH, renderOpenApiYaml } from '../../scripts/openapi-yaml.js';
import { buildOpenApiDocument, toOpenApiPath } from '../../src/main/http/contract/openapi.js';
import { operations } from '../../src/main/http/contract/operations.js';

const document = buildOpenApiDocument() as unknown as OpenAPIV3_1.Document;

describe('documento OpenAPI v1', () => {
  it('e um OpenAPI 3.1 valido, com todos os $ref resolvendo', async () => {
    await expect(SwaggerParser.validate(structuredClone(document))).resolves.toBeDefined();
  });

  it('cobre os quatro grupos do contrato', () => {
    const tags = new Set(operations.map((op) => op.tag));
    expect([...tags].sort()).toEqual(['access-events', 'auth', 'authorizations', 'users']);
  });

  it('tem operationId unico e um card de implementacao em cada rota', () => {
    const ids = operations.map((op) => op.operationId);
    expect(new Set(ids).size).toBe(ids.length);
    for (const op of operations) {
      const documented = document.paths?.[toOpenApiPath(op.path)]?.[op.method] as Record<string, unknown>;
      expect(documented.operationId).toBe(op.operationId);
      expect(documented['x-story']).toMatch(/^US-\d+$/);
    }
  });

  it('os exemplos de cada operacao passam nos proprios schemas', () => {
    for (const op of operations) {
      expect(op.params?.safeParse(op.example.params).success ?? true, `${op.operationId} params`).toBe(true);
      expect(op.query?.safeParse(op.example.query ?? {}).success ?? true, `${op.operationId} query`).toBe(true);
      expect(op.body?.safeParse(op.example.body).success ?? true, `${op.operationId} body`).toBe(true);
    }
  });

  it('docs/api/openapi.yaml esta em dia com o codigo (rode `npm run openapi:generate`)', async () => {
    const committed = (await readFile(OPENAPI_YAML_PATH, 'utf8')).replace(/\r\n/g, '\n');
    expect(committed).toBe(renderOpenApiYaml());
  });
});
