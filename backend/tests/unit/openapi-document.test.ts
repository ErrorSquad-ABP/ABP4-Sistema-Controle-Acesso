import { readFile } from 'node:fs/promises';
import SwaggerParser from '@apidevtools/swagger-parser';
import type { OpenAPIV3_1 } from 'openapi-types';
import { describe, expect, it } from 'vitest';
import { z } from 'zod';
import { OPENAPI_YAML_PATH, renderOpenApiYaml } from '../../scripts/openapi-yaml.js';
import { buildOpenApiDocument, isBodyRequired, toOpenApiPath } from '../../src/main/http/contract/openapi.js';
import { type Operation, operations } from '../../src/main/http/contract/operations.js';
import type { ContractMeta } from '../../src/main/http/contract/registry.js';
import { ErrorBody } from '../../src/main/http/contract/schemas/common.schemas.js';

const document = buildOpenApiDocument() as unknown as OpenAPIV3_1.Document;

function documented(op: Operation): OpenAPIV3_1.OperationObject {
  return document.paths?.[toOpenApiPath(op.path)]?.[op.method] as OpenAPIV3_1.OperationObject;
}

function byId(operationId: string): Operation {
  const op = operations.find((candidate) => candidate.operationId === operationId);
  if (!op) throw new Error(`operacao ${operationId} nao existe`);
  return op;
}

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
      const doc = documented(op) as OpenAPIV3_1.OperationObject & { 'x-story'?: string };
      expect(doc.operationId).toBe(op.operationId);
      expect(doc['x-story']).toMatch(/^US-\d+$/);
    }
  });

  it('login (rota publica) documenta o 401 de credencial invalida', () => {
    expect(documented(byId('login')).responses).toHaveProperty('401');
  });

  it('toda rota autenticada documenta 401 e toda rota ADMIN documenta 403', () => {
    for (const op of operations) {
      const { responses } = documented(op);
      if (op.access !== 'public') expect(responses, op.operationId).toHaveProperty('401');
      if (op.access === 'admin') expect(responses, op.operationId).toHaveProperty('403');
    }
  });

  it('requestBody so e obrigatorio quando o corpo vazio e invalido', () => {
    for (const op of operations.filter((candidate) => candidate.body)) {
      const body = documented(op).requestBody as OpenAPIV3_1.RequestBodyObject;
      expect(body.required, op.operationId).toBe(isBodyRequired(op));
    }
    expect(isBodyRequired(byId('cancelAuthorization'))).toBe(false);
    expect(isBodyRequired(byId('login'))).toBe(true);
  });

  it('leva descricoes e restricoes dos schemas nomeados para o documento', () => {
    const schemas = document.components?.schemas ?? {};
    expect(schemas.Role?.description).toContain('RESIDENT');
    expect(schemas.DenialReason?.description).toContain('OUT_OF_RANGE');
    expect(schemas.UpdateUserRequest).toMatchObject({ minProperties: 1 });
  });

  it('pedido de acesso QR exige token, terminal e posicao', () => {
    expect(document.components?.schemas?.QrAccessRequest).toMatchObject({
      required: ['qrToken', 'terminalId', 'position'],
    });
  });

  it('os exemplos de cada operacao passam nos proprios schemas', () => {
    for (const op of operations) {
      expect(op.params?.safeParse(op.example.params).success ?? true, `${op.operationId} params`).toBe(true);
      expect(op.query?.safeParse(op.example.query ?? {}).success ?? true, `${op.operationId} query`).toBe(true);
      expect(op.body?.safeParse(op.example.body).success ?? true, `${op.operationId} body`).toBe(true);
    }
  });

  it('fecha a entrada estrita da US-16 e mantem objetos de resposta abertos', () => {
    const schemas = document.components?.schemas ?? {};
    expect(schemas.CreateAuthorizationRequest).toMatchObject({ additionalProperties: false });
    expect(schemas.Authorization).not.toHaveProperty('additionalProperties', false);
  });

  it('docs/api/openapi.yaml esta em dia com o codigo (rode `npm run openapi:generate`)', async () => {
    const committed = (await readFile(OPENAPI_YAML_PATH, 'utf8')).replace(/\r\n/g, '\n');
    expect(committed).toBe(renderOpenApiYaml());
  });
});

describe('separacao entre entrada e saida', () => {
  // Contrato sintetico: `Amount` chega como texto e sai como numero.
  const registry = z.registry<ContractMeta>();
  const Amount = z.string().pipe(z.coerce.number());
  const Payment = z.object({ amount: Amount });
  const Receipt = z.object({ total: Amount });
  registry.add(Amount, { id: 'Amount' });
  registry.add(Payment, { id: 'Payment' });
  registry.add(Receipt, { id: 'Receipt' });
  registry.add(ErrorBody, { id: 'ErrorBody' });

  const base = { tag: 'auth', story: 'US-00', access: 'public', summary: 'teste' } as const;
  const synthetic = buildOpenApiDocument({
    registry,
    operations: [
      {
        ...base,
        operationId: 'pay',
        method: 'post',
        path: '/pay',
        body: Payment,
        success: { status: 200, description: 'ok', schema: Payment },
        example: { body: { amount: '10' } },
      },
      {
        ...base,
        operationId: 'receipt',
        method: 'get',
        path: '/receipt',
        success: { status: 200, description: 'ok', schema: Receipt },
        example: {},
      },
    ],
  }) as unknown as OpenAPIV3_1.Document;
  const schemas = synthetic.components?.schemas ?? {};
  const pay = synthetic.paths?.['/pay']?.post as OpenAPIV3_1.OperationObject;

  it('gera versoes diferentes quando entrada e saida divergem', () => {
    expect(schemas.Amount).toMatchObject({ type: 'string' });
    expect(schemas.AmountOutput).toMatchObject({ type: 'number' });
  });

  it('requisicao usa a versao de entrada e resposta a de saida', () => {
    const body = pay.requestBody as OpenAPIV3_1.RequestBodyObject;
    const ok = pay.responses?.['200'] as OpenAPIV3_1.ResponseObject;
    expect(body.content['application/json']?.schema).toEqual({ $ref: '#/components/schemas/Payment' });
    expect(ok.content?.['application/json']?.schema).toEqual({ $ref: '#/components/schemas/PaymentOutput' });
  });

  it('schema usado so na resposta mantem o nome base, apontando para as saidas', () => {
    expect(schemas).toHaveProperty('Receipt');
    expect(schemas).not.toHaveProperty('ReceiptOutput');
    expect(schemas.Receipt).toMatchObject({ properties: { total: { $ref: '#/components/schemas/AmountOutput' } } });
  });

  it('continua um OpenAPI valido', async () => {
    await expect(SwaggerParser.validate(structuredClone(synthetic))).resolves.toBeDefined();
  });
});
