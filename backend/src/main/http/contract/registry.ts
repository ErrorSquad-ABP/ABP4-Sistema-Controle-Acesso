import { z } from 'zod';

/**
 * Registro dos schemas nomeados do contrato v1. Todo schema registrado aqui
 * vira um `components.schemas.<id>` no OpenAPI e e referenciado por `$ref`.
 */
export interface ContractMeta {
  id: string;
  description?: string;
  /** Palavras-chave extras do JSON Schema que o Zod nao infere (ex.: refine -> minProperties). */
  jsonSchema?: Record<string, unknown>;
}

export const contractRegistry = z.registry<ContractMeta>();

/** Registra o schema com um nome publico no contrato e devolve o proprio schema. */
export function named<T extends z.ZodType>(
  id: string,
  schema: T,
  description?: string,
  jsonSchema?: Record<string, unknown>,
): T {
  const meta: ContractMeta = { id };
  if (description !== undefined) meta.description = description;
  if (jsonSchema !== undefined) meta.jsonSchema = jsonSchema;
  contractRegistry.add(schema, meta);
  return schema;
}
