import { z } from 'zod';
import { named } from '../registry.js';
import { DateTime, Id, PaginationQuery, page } from './common.schemas.js';

export const Role = named(
  'Role',
  z.enum(['ADMIN', 'RESIDENT', 'VISITOR']),
  'Perfil: ADMIN (administrador), RESIDENT (condomino), VISITOR (visitante)',
);

const Email = z.email().max(254).transform((v) => v.toLowerCase());
const Name = z.string().trim().min(2).max(120);
const Password = z.string().min(8).max(72).describe('Minimo 8 caracteres');

export const User = named(
  'User',
  z.object({
    id: Id,
    name: z.string(),
    email: z.email(),
    role: Role,
    active: z.boolean().describe('Usuario desativado nao faz login nem acessa'),
    createdAt: DateTime,
    updatedAt: DateTime,
  }),
);

/** Resumo do usuario embutido em autorizacoes e eventos. */
export const UserSummary = named(
  'UserSummary',
  z.object({ id: Id, name: z.string(), role: Role }),
);

export const UserPage = page('UserPage', User);

export const CreateUserRequest = named(
  'CreateUserRequest',
  z.object({
    name: Name,
    email: Email,
    password: Password,
    role: Role,
  }),
);

export const UpdateUserRequest = named(
  'UpdateUserRequest',
  z
    .object({
      name: Name.optional(),
      email: Email.optional(),
      password: Password.optional(),
      role: Role.optional(),
      active: z.boolean().optional(),
    })
    .refine((v) => Object.values(v).some((field) => field !== undefined), {
      message: 'Informe ao menos um campo para atualizar',
    }),
  'Atualizacao parcial: envie so os campos que mudam',
);

export const ListUsersQuery = PaginationQuery.extend({
  role: Role.optional(),
  active: z
    .enum(['true', 'false'])
    .transform((v) => v === 'true')
    .optional()
    .describe('Filtra por ativo (true) ou desativado (false)'),
  search: z.string().trim().min(1).max(120).optional().describe('Busca por nome ou e-mail'),
});
