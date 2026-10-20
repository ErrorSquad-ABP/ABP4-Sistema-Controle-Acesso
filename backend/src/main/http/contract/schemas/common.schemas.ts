import { z } from 'zod';
import { named } from '../registry.js';

export const Id = z.uuid().describe('Identificador (UUID)');

/** Data/hora ISO 8601. Na entrada aceita offset (`-03:00`); a API sempre devolve em UTC (`Z`). */
export const DateTime = z.iso.datetime({ offset: true }).describe('Data/hora ISO 8601');

export const IdParams = z.object({ id: Id });

export const PaginationQuery = z.object({
  page: z.coerce.number().int().min(1).default(1).describe('Pagina, comecando em 1'),
  pageSize: z.coerce.number().int().min(1).max(100).default(20).describe('Itens por pagina (max. 100)'),
});

/** Envelope de listas paginadas: `{ items, page, pageSize, total }`. */
export function page<T extends z.ZodType>(id: string, item: T) {
  return named(
    id,
    z.object({
      items: z.array(item),
      page: z.int().min(1),
      pageSize: z.int().min(1),
      total: z.int().min(0).describe('Total de itens considerando os filtros'),
    }),
  );
}

/** Intervalo opcional `from`/`to` usado nos filtros de listagem. */
export const PeriodQuery = z.object({
  from: DateTime.optional().describe('Inicio do periodo (inclusivo)'),
  to: DateTime.optional().describe('Fim do periodo (inclusivo)'),
});

export function refinePeriod<T extends { from?: string | undefined; to?: string | undefined }>(
  value: T,
  ctx: z.RefinementCtx,
): void {
  if (value.from && value.to && Date.parse(value.from) > Date.parse(value.to)) {
    ctx.addIssue({ code: 'custom', path: ['to'], message: '`to` deve ser igual ou posterior a `from`' });
  }
}

export const ErrorBody = named(
  'ErrorBody',
  z.object({
    error: z.object({
      code: z.string().describe('Codigo estavel do erro (ex.: INVALID_REQUEST, NOT_FOUND)'),
      message: z.string().describe('Mensagem legivel'),
      details: z.unknown().optional().describe('Detalhes por campo, quando houver'),
    }),
  }),
  'Formato unico de erro da API',
);
