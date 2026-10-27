import { z } from 'zod';
import { type Operation, operations } from './operations.js';
import { type ContractMeta, contractRegistry } from './registry.js';
// Importa so pelo efeito: registra ErrorBody mesmo sem operacao que o use direto.
import './schemas/common.schemas.js';

/** Prefixo em que o contrato v1 e montado no Express. */
export const API_V1_PREFIX = '/api/v1';

type JsonSchema = Record<string, unknown>;

/**
 * Lado do contrato: `input` e o que o cliente envia (antes de transform/default);
 * `output` e o que a API devolve (depois deles).
 */
type Io = 'input' | 'output';

type ContractRegistry = z.core.$ZodRegistry<ContractMeta>;

export interface ContractSource {
  operations: readonly Operation[];
  registry: ContractRegistry;
}

const REF_PREFIX = '#/components/schemas/';
const OUTPUT_SUFFIX = 'Output';

const TAGS = [
  { name: 'auth', description: 'Login e sessao (JWT)' },
  { name: 'users', description: 'Cadastro de usuarios (administrador)' },
  { name: 'authorizations', description: 'Liberacoes de acesso: pessoa + local + janela + usos' },
  { name: 'access-events', description: 'Solicitacao de acesso por QR e historico de tentativas' },
  { name: 'credentials', description: 'Validacao criptografica de credenciais QR' },
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
      // O modo output fecha todo objeto; num contrato isso faria o cliente rejeitar
      // campo novo na resposta, que precisa continuar sendo mudanca compativel.
      if (key === 'additionalProperties' && value === false) continue;
      out[key] = visit(value);
    }
    // Limites de Number.MAX_SAFE_INTEGER que o Zod poe em todo inteiro.
    if (out.maximum === Number.MAX_SAFE_INTEGER) delete out.maximum;
    if (out.minimum === Number.MIN_SAFE_INTEGER) delete out.minimum;
    return out;
  };
  return visit(schema) as JsonSchema;
}

/** Nomes de componente referenciados (`$ref`) dentro de um no. */
function refsIn(node: unknown, found = new Set<string>()): Set<string> {
  if (Array.isArray(node)) {
    for (const item of node) refsIn(item, found);
  } else if (node !== null && typeof node === 'object') {
    for (const [key, value] of Object.entries(node)) {
      if (key === '$ref' && typeof value === 'string' && value.startsWith(REF_PREFIX)) {
        found.add(value.slice(REF_PREFIX.length));
      } else {
        refsIn(value, found);
      }
    }
  }
  return found;
}

/** Troca `$ref`s segundo `rename` (nome antigo -> novo). */
function renameRefs<T>(node: T, rename: (name: string) => string): T {
  return JSON.parse(
    JSON.stringify(node).replace(/"#\/components\/schemas\/([^"]+)"/g, (_match, name: string) =>
      JSON.stringify(`${REF_PREFIX}${rename(name)}`),
    ),
  ) as T;
}

/** Tira `optional`/`default` de volta ao schema de base (que pode ser nomeado). */
function unwrap(schema: z.ZodType): z.ZodType {
  if (schema instanceof z.ZodOptional || schema instanceof z.ZodDefault) {
    return unwrap(schema.unwrap() as z.ZodType);
  }
  return schema;
}

/** Converte os schemas do contrato para JSON Schema, separando entrada e saida. */
function createConverter(registry: ContractRegistry) {
  const options = (io: Io) => ({
    io,
    unrepresentable: 'any' as const,
    // O Zod nao copia metadados de registry proprio: aplica descricao e extras daqui.
    override: (ctx: { zodSchema: unknown; jsonSchema: JsonSchema }) => {
      const meta = registry.get(ctx.zodSchema as z.ZodType);
      if (meta?.description) ctx.jsonSchema.description = meta.description;
      if (meta?.jsonSchema) Object.assign(ctx.jsonSchema, meta.jsonSchema);
    },
  });

  const convertAll = (io: Io): Record<string, JsonSchema> => {
    const { schemas } = z.toJSONSchema(registry, {
      ...options(io),
      uri: (id) => `${REF_PREFIX}${id}`,
    }) as { schemas: Record<string, JsonSchema> };
    return Object.fromEntries(Object.entries(schemas).map(([id, schema]) => [id, clean(schema)]));
  };

  const input = convertAll('input');
  const output = convertAll('output');

  // Nomeados cuja saida difere da entrada — inclusive por referenciar outro que difere.
  const divergent = new Set(
    Object.keys(input).filter((id) => JSON.stringify(input[id]) !== JSON.stringify(output[id])),
  );
  for (let grew = true; grew; ) {
    grew = false;
    for (const id of Object.keys(output)) {
      if (!divergent.has(id) && [...refsIn(output[id])].some((ref) => divergent.has(ref))) {
        divergent.add(id);
        grew = true;
      }
    }
  }

  /** Entrada mantem o nome; saida que diverge ganha o sufixo `Output`. */
  const nameFor = (id: string, io: Io) =>
    io === 'output' && divergent.has(id) ? `${id}${OUTPUT_SUFFIX}` : id;

  return {
    /** Todos os candidatos a componente; os nao usados saem em `prune`. */
    components(): Record<string, JsonSchema> {
      const all: Record<string, JsonSchema> = { ...input };
      for (const id of divergent) {
        all[nameFor(id, 'output')] = renameRefs(output[id] as JsonSchema, (ref) => nameFor(ref, 'output'));
      }
      return all;
    },

    /** `$ref` para schema nomeado (mesmo envolto em optional/default); senao o JSON Schema inline. */
    schemaFor(schema: z.ZodType, io: Io): JsonSchema {
      const id = registry.get(unwrap(schema))?.id;
      if (!id) return clean(z.toJSONSchema(schema, options(io)) as JsonSchema);

      const ref: JsonSchema = { $ref: `${REF_PREFIX}${nameFor(id, io)}` };
      if (schema instanceof z.ZodDefault) ref.default = schema.def.defaultValue;
      return ref;
    },
  };
}

type Converter = ReturnType<typeof createConverter>;

function parametersFor(op: Operation, convert: Converter): JsonSchema[] {
  const fromObject = (location: 'path' | 'query', object: z.ZodObject | undefined) =>
    Object.entries(object?.shape ?? {}).map(([name, field]) => {
      const fieldSchema = field as z.ZodType;
      const { description, ...schema } = convert.schemaFor(fieldSchema, 'input');
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

function responsesFor(op: Operation, convert: Converter): JsonSchema {
  const success: JsonSchema = { description: op.success.description };
  if (op.success.schema) {
    success.content = { 'application/json': { schema: convert.schemaFor(op.success.schema, 'output') } };
  }
  const responses: JsonSchema = { [String(op.success.status)]: success };
  const ref = (name: string) => ({ $ref: `#/components/responses/${name}` });

  if (op.params || op.query || op.body) responses['400'] = ref('BadRequest');
  if (op.access !== 'public' || op.extraErrors?.includes(401)) responses['401'] = ref('Unauthorized');
  if (op.access === 'admin') responses['403'] = ref('Forbidden');
  if (op.params?.shape.id) responses['404'] = ref('NotFound');
  if (op.extraErrors?.includes(409)) responses['409'] = ref('Conflict');
  if (op.extraErrors?.includes(422)) responses['422'] = ref('UnprocessableEntity');
  if (op.extraErrors?.includes(429)) responses['429'] = ref('TooManyRequests');
  if (op.extraErrors?.includes(503)) responses['503'] = ref('ServiceUnavailable');
  return responses;
}

/** Mesmo criterio das rotas stub, que tratam corpo ausente como `{}`. */
export function isBodyRequired(op: Operation): boolean {
  return op.body !== undefined && !op.body.safeParse({}).success;
}

function operationObject(op: Operation, convert: Converter): JsonSchema {
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

  const parameters = parametersFor(op, convert);
  if (parameters.length > 0) object.parameters = parameters;
  if (op.body) {
    object.requestBody = {
      // Obrigatorio so se o corpo vazio for invalido (ex.: cancelar aceita sem corpo).
      required: isBodyRequired(op),
      content: {
        'application/json': { schema: convert.schemaFor(op.body, 'input'), example: op.example.body },
      },
    };
  }
  object.responses = responsesFor(op, convert);
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

/**
 * Mantem so os componentes alcancaveis a partir das rotas e respostas padrao.
 * Se de um schema so a versao de saida e usada, ela volta ao nome base.
 */
function prune(
  candidates: Record<string, JsonSchema>,
  roots: unknown[],
): { schemas: Record<string, JsonSchema>; rename: (name: string) => string } {
  const used = new Set<string>();
  const pending = [...refsIn(roots)];
  while (pending.length > 0) {
    const name = pending.pop() as string;
    if (used.has(name) || candidates[name] === undefined) continue;
    used.add(name);
    pending.push(...refsIn(candidates[name]));
  }

  const rename = (name: string) => {
    const base = name.endsWith(OUTPUT_SUFFIX) ? name.slice(0, -OUTPUT_SUFFIX.length) : name;
    return base !== name && candidates[base] !== undefined && !used.has(base) ? base : name;
  };
  const schemas = Object.fromEntries(
    [...used]
      .map((name) => [rename(name), renameRefs(candidates[name] as JsonSchema, rename)] as const)
      .sort(([a], [b]) => a.localeCompare(b)),
  );
  return { schemas, rename };
}

export function buildOpenApiDocument(
  source: ContractSource = { operations, registry: contractRegistry },
): JsonSchema {
  const convert = createConverter(source.registry);

  const paths: Record<string, JsonSchema> = {};
  for (const op of source.operations) {
    const path = toOpenApiPath(op.path);
    paths[path] = { ...paths[path], [op.method]: operationObject(op, convert) };
  }

  const responses = {
    BadRequest: errorResponse('Entrada invalida (INVALID_REQUEST, com erros por campo em details) ou JSON malformado (INVALID_JSON)'),
    Unauthorized: errorResponse('Token ausente, invalido ou expirado (UNAUTHORIZED)'),
    Forbidden: errorResponse('Perfil sem permissao para a operacao (FORBIDDEN)'),
    NotFound: errorResponse('Recurso nao encontrado (NOT_FOUND)'),
    Conflict: errorResponse('Conflito com o estado atual (CONFLICT)'),
    UnprocessableEntity: errorResponse('Regra de negocio violada (VALIDATION_ERROR)'),
    TooManyRequests: errorResponse('Muitas requisicoes em pouco tempo (TOO_MANY_REQUESTS)'),
    ServiceUnavailable: errorResponse('Dependencia indisponivel no processo, como banco nao configurado (SERVICE_UNAVAILABLE)'),
  };

  const { schemas, rename } = prune(convert.components(), [paths, responses]);

  return {
    openapi: '3.1.0',
    info: {
      title: 'ABP4 · Sistema de Controle de Acesso',
      version: '1.0.0',
      description: DESCRIPTION,
    },
    servers: [{ url: API_V1_PREFIX, description: 'Mesmo host da API' }],
    tags: TAGS,
    paths: renameRefs(paths, rename),
    components: {
      schemas,
      responses,
      securitySchemes: {
        bearerAuth: { type: 'http', scheme: 'bearer', bearerFormat: 'JWT' },
      },
    },
  };
}
