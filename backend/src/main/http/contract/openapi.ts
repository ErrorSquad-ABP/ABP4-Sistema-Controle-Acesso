import { z } from 'zod';
import { type Operation, operations } from './operations.js';
import { contractRegistry } from './registry.js';
// Importa so pelo efeito: registra ErrorBody mesmo sem operacao que o use direto.
import './schemas/common.schemas.js';

/** Prefixo em que o contrato v1 e montado no Express. */
export const API_V1_PREFIX = '/api/v1';

type JsonSchema = Record<string, unknown>;

const REF_PREFIX = '#/components/schemas/';
const TO_JSON_OPTIONS = { io: 'input', unrepresentable: 'any' } as const;

const TAGS = [
  { name: 'auth', description: 'Login e sessao (JWT)' },
  { name: 'users', description: 'Cadastro de usuarios (administrador)' },
  { name: 'authorizations', description: 'Liberacoes de acesso: pessoa + local + janela + usos' },
  { name: 'access-events', description: 'Solicitacao de acesso por QR e historico de tentativas' },
];

const DESCRIPTION = `Contrato REST v1 do Sistema de Controle de Acesso (ErrorSquad · FATEC).

- Autenticacao: \`Authorization: Bearer <accessToken>\` (obtido em \`POST /auth/login\`).
- Datas em ISO 8601; respostas sempre em UTC.
- Erros sempre no formato \`{ "error": { "code", "message", "details?" } }\`.
- Listas paginadas: \`{ items, page, pageSize, total }\`.

Rotas ainda nao implementadas respondem **501 NOT_IMPLEMENTED** depois de validar a entrada;
o card responsavel aparece em \`x-story\` de cada operacao.`;

/** Remove ruido que o Zod gera e o OpenAPI nao precisa. */
function clean(schema: JsonSchema): JsonSchema {
  const visit = (node: unknown): unknown => {
    if (Array.isArray(node)) return node.map(visit);
    if (node === null || typeof node !== 'object') return node;
    const out: JsonSchema = {};
    for (const [key, value] of Object.entries(node)) {
      if (key === '$schema' || key === '$id') continue;
      // `format` (uuid, email, date-time) ja descreve; o regex do Zod so polui o documento.
      if (key === 'pattern' && 'format' in node) continue;
      out[key] = visit(value);
    }
    // Limites de Number.MAX_SAFE_INTEGER que o Zod poe em todo inteiro.
    if (out.maximum === Number.MAX_SAFE_INTEGER) delete out.maximum;
    if (out.minimum === Number.MIN_SAFE_INTEGER) delete out.minimum;
    return out;
  };
  return visit(schema) as JsonSchema;
}

/** Tira `optional`/`default` de volta ao schema de base (que pode ser nomeado). */
function unwrap(schema: z.ZodType): z.ZodType {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault) {
    return unwrap(schema.unwrap() as z.ZodType);
  }
  return schema;
}

/** `$ref` para schema nomeado (mesmo envolto em optional/default); senao o JSON Schema inline. */
function schemaFor(schema: z.ZodType): JsonSchema {
  const id = contractRegistry.get(unwrap(schema))?.id;
  if (!id) return clean(z.toJSONSchema(schema, TO_JSON_OPTIONS) as JsonSchema);

  const ref: JsonSchema = { $ref: `${REF_PREFIX}${id}` };
  if (schema instanceof z.ZodDefault) ref.default = schema.def.defaultValue;
  return ref;
}

function componentSchemas(): Record<string, JsonSchema> {
  const { schemas } = z.toJSONSchema(contractRegistry, {
    ...TO_JSON_OPTIONS,
    uri: (id) => `${REF_PREFIX}${id}`,
  }) as { schemas: Record<string, JsonSchema> };
  return Object.fromEntries(
    Object.keys(schemas)
      .sort()
      .map((id) => [id, clean(schemas[id] as JsonSchema)]),
  );
}

function parametersFor(op: Operation): JsonSchema[] {
  const fromObject = (location: 'path' | 'query', object: z.ZodObject | undefined) =>
    Object.entries(object?.shape ?? {}).map(([name, field]) => {
      const fieldSchema = field as z.ZodType;
      const { description, ...schema } = schemaFor(fieldSchema);
      const param: JsonSchema = {
        name,
        in: location,
        required: location === 'path' || !fieldSchema.safeParse(undefined).success,
        schema,
      };
      if (typeof description === 'string') param.description = description;
      return param;
    });
  return [...fromObject('path', op.params), ...fromObject('query', op.query)];
}

function responsesFor(op: Operation): JsonSchema {
  const success: JsonSchema = { description: op.success.description };
  if (op.success.schema) {
    success.content = { 'application/json': { schema: schemaFor(op.success.schema) } };
  }
  const responses: JsonSchema = { [String(op.success.status)]: success };
  const ref = (name: string) => ({ $ref: `#/components/responses/${name}` });

  if (op.params || op.query || op.body) responses['400'] = ref('BadRequest');
  if (op.access !== 'public') responses['401'] = ref('Unauthorized');
  if (op.access === 'admin') responses['403'] = ref('Forbidden');
  if (op.params?.shape.id) responses['404'] = ref('NotFound');
  if (op.businessErrors?.includes(409)) responses['409'] = ref('Conflict');
  if (op.businessErrors?.includes(422)) responses['422'] = ref('UnprocessableEntity');
  return responses;
}

function operationObject(op: Operation): JsonSchema {
  const object: JsonSchema = {
    operationId: op.operationId,
    tags: [op.tag],
    summary: op.summary,
  };
  const notes = [op.description, op.access === 'admin' ? 'Restrito ao perfil ADMIN.' : undefined];
  const description = notes.filter(Boolean).join('\n\n');
  if (description) object.description = description;
  object['x-story'] = op.story;
  object.security = op.access === 'public' ? [] : [{ bearerAuth: [] }];

  const parameters = parametersFor(op);
  if (parameters.length > 0) object.parameters = parameters;
  if (op.body) {
    object.requestBody = {
      required: true,
      content: { 'application/json': { schema: schemaFor(op.body), example: op.example.body } },
    };
  }
  object.responses = responsesFor(op);
  return object;
}

/** `/users/:id` (Express) -> `/users/{id}` (OpenAPI). */
export function toOpenApiPath(expressPath: string): string {
  return expressPath.replace(/:(\w+)/g, '{$1}');
}

function errorResponse(description: string) {
  return {
    description,
    content: { 'application/json': { schema: { $ref: `${REF_PREFIX}ErrorBody` } } },
  };
}

export function buildOpenApiDocument(): JsonSchema {
  const paths: Record<string, JsonSchema> = {};
  for (const op of operations) {
    const path = toOpenApiPath(op.path);
    paths[path] = { ...paths[path], [op.method]: operationObject(op) };
  }

  return {
    openapi: '3.1.0',
    info: {
      title: 'ABP4 · Sistema de Controle de Acesso',
      version: '1.0.0',
      description: DESCRIPTION,
    },
    servers: [{ url: API_V1_PREFIX, description: 'Mesmo host da API' }],
    tags: TAGS,
    paths,
    components: {
      schemas: componentSchemas(),
      responses: {
        BadRequest: errorResponse('Entrada invalida (INVALID_REQUEST, com erros por campo em details) ou JSON malformado (INVALID_JSON)'),
        Unauthorized: errorResponse('Token ausente, invalido ou expirado (UNAUTHORIZED)'),
        Forbidden: errorResponse('Perfil sem permissao para a operacao (FORBIDDEN)'),
        NotFound: errorResponse('Recurso nao encontrado (NOT_FOUND)'),
        Conflict: errorResponse('Conflito com o estado atual (CONFLICT)'),
        UnprocessableEntity: errorResponse('Regra de negocio violada (VALIDATION_ERROR)'),
      },
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
  };
}
