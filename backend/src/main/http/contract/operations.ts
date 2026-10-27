import type { z } from 'zod';
import {
  AccessEventPage,
  AccessResult,
  ListAccessEventsQuery,
  ListMyAccessEventsQuery,
  QrAccessRequest,
} from './schemas/access-events.schemas.js';
import { LoginRequest, LoginResponse } from './schemas/auth.schemas.js';
import {
  Authorization,
  AuthorizationPage,
  CancelAuthorizationRequest,
  CreateAuthorizationRequest,
  ListAuthorizationsQuery,
  ListMyAuthorizationsQuery,
} from './schemas/authorizations.schemas.js';
import { IdParams } from './schemas/common.schemas.js';
import {
  CreateUserRequest,
  ListUsersQuery,
  UpdateUserRequest,
  User,
  UserPage,
} from './schemas/users.schemas.js';

/**
 * Contrato REST v1 — fonte unica das rotas. Daqui saem as rotas stub do
 * Express (validacao Zod + 501) e o documento OpenAPI (docs/api/openapi.yaml).
 * Rota nova ou alterada: edite aqui e rode `npm run openapi:generate`.
 */

export type ContractTag = 'auth' | 'users' | 'authorizations' | 'access-events';

/** public: sem token · authenticated: qualquer perfil logado · admin: so ADMIN. */
export type Access = 'public' | 'authenticated' | 'admin';

export interface Operation {
  operationId: string;
  method: 'get' | 'post' | 'patch' | 'delete';
  /** Caminho relativo a /api/v1, no formato do Express (`/users/:id`). */
  path: string;
  tag: ContractTag;
  summary: string;
  description?: string;
  /** Card que implementa a rota de verdade (ate la ela responde 501). */
  story: string;
  access: Access;
  params?: z.ZodObject;
  query?: z.ZodObject;
  body?: z.ZodType;
  success: { status: 200 | 201 | 204; description: string; schema?: z.ZodType };
  /**
   * Respostas de erro alem das derivadas de `access`/params/body. Rota publica
   * que pode negar credencial (login) declara 401 aqui.
   */
  extraErrors?: (401 | 409 | 422 | 429 | 503)[];
  /** Requisicao valida de exemplo: vira exemplo no OpenAPI e e usada nos testes. */
  example: { params?: Record<string, string>; query?: Record<string, string>; body?: unknown };
}

export const EXAMPLE_IDS = {
  user: '7c9e6679-7425-40de-944b-e07fc1f90ae7',
  location: '1b4e28ba-2fa1-41d2-883f-0016d3cca427',
  authorization: '6ec0bd7f-11c0-43da-975e-2a8ad9ebae0b',
} as const;

export const operations: readonly Operation[] = [
  // ---------------------------------------------------------------- auth
  {
    operationId: 'login',
    method: 'post',
    path: '/auth/login',
    tag: 'auth',
    summary: 'Entrar com e-mail e senha',
    description: 'Devolve o JWT e o usuario logado. Credencial invalida ou usuario desativado -> 401.',
    story: 'US-14',
    access: 'public',
    body: LoginRequest,
    success: { status: 200, description: 'Login realizado', schema: LoginResponse },
    extraErrors: [401, 429, 503],
    example: { body: { email: 'maria.souza@exemplo.com', password: 'senha-forte-123' } },
  },
  {
    operationId: 'getCurrentUser',
    method: 'get',
    path: '/auth/me',
    tag: 'auth',
    summary: 'Usuario da sessao atual',
    story: 'US-14',
    access: 'authenticated',
    success: { status: 200, description: 'Usuario logado', schema: User },
    extraErrors: [429, 503],
    example: {},
  },

  // --------------------------------------------------------------- users
  {
    operationId: 'listUsers',
    method: 'get',
    path: '/users',
    tag: 'users',
    summary: 'Listar usuarios',
    story: 'US-15',
    access: 'admin',
    query: ListUsersQuery,
    success: { status: 200, description: 'Pagina de usuarios', schema: UserPage },
    example: { query: { role: 'VISITOR', active: 'true', page: '1' } },
  },
  {
    operationId: 'createUser',
    method: 'post',
    path: '/users',
    tag: 'users',
    summary: 'Cadastrar usuario',
    description: 'E-mail ja cadastrado -> 409.',
    story: 'US-15',
    access: 'admin',
    body: CreateUserRequest,
    success: { status: 201, description: 'Usuario criado', schema: User },
    extraErrors: [409],
    example: {
      body: { name: 'Maria Souza', email: 'maria.souza@exemplo.com', password: 'senha-forte-123', role: 'VISITOR' },
    },
  },
  {
    operationId: 'getUser',
    method: 'get',
    path: '/users/:id',
    tag: 'users',
    summary: 'Detalhar usuario',
    story: 'US-15',
    access: 'admin',
    params: IdParams,
    success: { status: 200, description: 'Usuario', schema: User },
    example: { params: { id: EXAMPLE_IDS.user } },
  },
  {
    operationId: 'updateUser',
    method: 'patch',
    path: '/users/:id',
    tag: 'users',
    summary: 'Atualizar usuario',
    description: 'Atualizacao parcial; `active: false` desativa o usuario. E-mail ja usado por outro -> 409.',
    story: 'US-15',
    access: 'admin',
    params: IdParams,
    body: UpdateUserRequest,
    success: { status: 200, description: 'Usuario atualizado', schema: User },
    extraErrors: [409],
    example: { params: { id: EXAMPLE_IDS.user }, body: { role: 'RESIDENT' } },
  },
  {
    operationId: 'deleteUser',
    method: 'delete',
    path: '/users/:id',
    tag: 'users',
    summary: 'Remover usuario',
    description: 'Exclusao logica: o usuario e desativado e o historico de acessos e preservado.',
    story: 'US-15',
    access: 'admin',
    params: IdParams,
    success: { status: 204, description: 'Usuario removido' },
    example: { params: { id: EXAMPLE_IDS.user } },
  },

  // ------------------------------------------------------ authorizations
  {
    operationId: 'listMyAuthorizations',
    method: 'get',
    path: '/me/authorizations',
    tag: 'authorizations',
    summary: 'Minhas autorizacoes',
    description: 'Autorizacoes do usuario logado (tela "Minhas autorizacoes" do app).',
    story: 'US-18',
    access: 'authenticated',
    query: ListMyAuthorizationsQuery,
    success: { status: 200, description: 'Pagina de autorizacoes', schema: AuthorizationPage },
    example: { query: { status: 'ACTIVE' } },
  },
  {
    operationId: 'listAuthorizations',
    method: 'get',
    path: '/authorizations',
    tag: 'authorizations',
    summary: 'Listar autorizacoes',
    story: 'US-17',
    access: 'admin',
    query: ListAuthorizationsQuery,
    success: { status: 200, description: 'Pagina de autorizacoes', schema: AuthorizationPage },
    example: { query: { userId: EXAMPLE_IDS.user, status: 'ACTIVE' } },
  },
  {
    operationId: 'createAuthorization',
    method: 'post',
    path: '/authorizations',
    tag: 'authorizations',
    summary: 'Criar autorizacao',
    description: 'Usuario ou local inexistente -> 422.',
    story: 'US-16',
    access: 'admin',
    body: CreateAuthorizationRequest,
    success: { status: 201, description: 'Autorizacao criada', schema: Authorization },
    extraErrors: [422],
    example: {
      body: {
        userId: EXAMPLE_IDS.user,
        locationId: EXAMPLE_IDS.location,
        startsAt: '2026-10-20T14:00:00-03:00',
        endsAt: '2026-10-20T18:00:00-03:00',
        maxUses: 5,
      },
    },
  },
  {
    operationId: 'getAuthorization',
    method: 'get',
    path: '/authorizations/:id',
    tag: 'authorizations',
    summary: 'Detalhar autorizacao',
    description: 'ADMIN ve qualquer uma; os demais perfis so as proprias (de outro usuario -> 404).',
    story: 'US-17',
    access: 'authenticated',
    params: IdParams,
    success: { status: 200, description: 'Autorizacao', schema: Authorization },
    example: { params: { id: EXAMPLE_IDS.authorization } },
  },
  {
    operationId: 'cancelAuthorization',
    method: 'post',
    path: '/authorizations/:id/cancel',
    tag: 'authorizations',
    summary: 'Cancelar autorizacao',
    description: 'Corpo opcional (so o motivo). Ja cancelada ou expirada -> 409.',
    story: 'US-17',
    access: 'admin',
    params: IdParams,
    body: CancelAuthorizationRequest,
    success: { status: 200, description: 'Autorizacao cancelada', schema: Authorization },
    extraErrors: [409],
    example: { params: { id: EXAMPLE_IDS.authorization }, body: { reason: 'Visita remarcada' } },
  },

  // ------------------------------------------------------- access-events
  {
    operationId: 'requestQrAccess',
    method: 'post',
    path: '/access-events/qr',
    tag: 'access-events',
    summary: 'Solicitar acesso com o QR do terminal',
    description:
      'O app envia o token lido do QR, o terminal e a localizacao; o usuario vem do JWT. A API valida ' +
      'o token (formato, terminal e validade de 10 s), a autorizacao (janela, usos, local) e a distancia ' +
      '(ate 100 m); se liberar, envia o comando de abertura ao terminal. `terminalId` diferente do ' +
      'terminal do token -> DENIED com INVALID_CREDENTIAL. Toda tentativa vira um evento: negar ' +
      'acesso devolve 200 com `decision: DENIED` e o motivo.',
    story: 'US-20',
    access: 'authenticated',
    body: QrAccessRequest,
    success: { status: 200, description: 'Decisao do acesso (liberado ou negado)', schema: AccessResult },
    example: {
      body: {
        qrToken: 'eyJ0ZXJtaW5hbCI6ImF1cm9yYS1yZWNlcGNhbyJ9.exemplo',
        terminalId: 'aurora-recepcao',
        position: { latitude: -23.1857, longitude: -45.8846, accuracyMeters: 12 },
      },
    },
  },
  {
    operationId: 'listMyAccessEvents',
    method: 'get',
    path: '/me/access-events',
    tag: 'access-events',
    summary: 'Meu historico de acessos',
    story: 'US-21',
    access: 'authenticated',
    query: ListMyAccessEventsQuery,
    success: { status: 200, description: 'Pagina de eventos', schema: AccessEventPage },
    extraErrors: [429, 503],
    example: { query: { from: '2026-10-01T00:00:00-03:00' } },
  },
  {
    operationId: 'listAccessEvents',
    method: 'get',
    path: '/access-events',
    tag: 'access-events',
    summary: 'Historico de acessos',
    description: 'Todas as tentativas (aceitas e negadas), com filtros.',
    story: 'US-21',
    access: 'admin',
    query: ListAccessEventsQuery,
    success: { status: 200, description: 'Pagina de eventos', schema: AccessEventPage },
    extraErrors: [429, 503],
    example: { query: { decision: 'DENIED', method: 'QR', from: '2026-10-01T00:00:00Z', to: '2026-10-31T23:59:59Z' } },
  },
];

