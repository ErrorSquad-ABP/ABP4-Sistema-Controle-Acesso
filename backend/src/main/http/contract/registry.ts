import { z } from 'zod';

/**
 * Registro dos schemas nomeados do contrato v1. Todo schema registrado aqui
 * vira um `components.schemas.<id>` no OpenAPI e e referenciado por `$ref`.
 */
export interface ContractMeta {
  id: string;
  description?: string;
}

export const contractRegistry = z.registry<ContractMeta>();

/** Registra o schema com um nome publico no contrato e devolve o proprio schema. */
export function named<T extends z.ZodType>(id: string, schema: T, description?: string): T {
  contractRegistry.add(schema, description === undefined ? { id } : { id, description });
  return schema;
}
