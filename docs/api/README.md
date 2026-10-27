# API REST v1 — contrato

O contrato da API está em [`openapi.yaml`](openapi.yaml) (OpenAPI 3.1), congelado na US-06 para o app Flutter integrar sem esperar a implementação do backend.

## Onde ver

| Onde | O que é |
|---|---|
| `GET /docs` | **Swagger UI** servido pela própria API, com "Try it out" e botão *Authorize* para o JWT |
| `GET /openapi.json` | o mesmo documento em JSON, para ferramentas e geradores de cliente |
| [`docs/api/openapi.yaml`](openapi.yaml) | cópia versionada no repo, para ler no GitHub ou importar no Postman/Insomnia |

Localmente: `cd backend && npm run dev` e abra <http://localhost:3000/docs>. Em produção, o mesmo caminho no domínio do Vercel (US-13).

## Rotas (prefixo `/api/v1`)

| Grupo | Método e rota | Perfil | Card |
|---|---|---|---|
| auth | `POST /auth/login` | público | US-14 |
| auth | `GET /auth/me` | logado | US-14 |
| users | `GET /users` · `POST /users` | ADMIN | US-15 |
| users | `GET` · `PATCH` · `DELETE /users/{id}` | ADMIN | US-15 |
| authorizations | `GET /me/authorizations` | logado | US-18 |
| authorizations | `GET /authorizations` · `POST /authorizations` | ADMIN | US-17 · US-16 |
| authorizations | `GET /authorizations/{id}` | ADMIN ou dono | US-17 |
| authorizations | `POST /authorizations/{id}/cancel` | ADMIN | US-17 |
| access-events | `POST /access-events/qr` | logado | US-20 |
| credentials | `POST /credentials/qr/validate` | logado | US-19 (roteamento depende da US-14) |
| access-events | `GET /me/access-events` | logado | US-21 |
| access-events | `GET /access-events` | ADMIN | US-21 |

**Hoje todas são stubs**: validam a entrada com Zod (inválida → `400 INVALID_REQUEST`) e respondem `501 NOT_IMPLEMENTED` citando o card. Quando o card da rota for entregue, ela passa a responder de verdade, sem mudar o contrato.

## Convenções

- **Autenticação**: `Authorization: Bearer <accessToken>` (de `POST /auth/login`).
- **Datas**: ISO 8601. Na entrada aceita offset (`2026-10-20T14:00:00-03:00`); na resposta sempre UTC (`Z`).
- **Erros**: `{ "error": { "code", "message", "details?" } }` — tabela de códigos em [`caso-de-uso-modelo.md`](../architecture/caso-de-uso-modelo.md#erros-do-domínio-ao-http).
- **Listas**: `{ items, page, pageSize, total }`; `page` começa em 1, `pageSize` padrão 20 (máx. 100).
- **Pedido de acesso QR**: o app envia `qrToken` (lido do QR), `terminalId` e `position`; o usuário vem do JWT. O backend confere se o `terminalId` bate com o terminal assinado dentro do token — divergiu, nega com `INVALID_CREDENTIAL`.
- **Validação de credencial QR**: `POST /credentials/qr/validate` recebe `qrToken` e `terminalId`. O QR leva claims em Base64URL (`terminalId`, `issuedAt`, `expiresAt`, `id`) seguidos da assinatura HMAC-SHA-256. Responde `{ valid: true, terminalId, expiresAt }` ou `{ valid: false }`. O token rotativo é efêmero e não é persistido como `Credential`. A validação não concede acesso, consulta autorização, calcula geofence nem grava eventos. Exige sessão conforme a US-14; enquanto o middleware JWT não estiver implementado, a operação permanece em `501` depois da validação de formato.
- **Acesso negado não é erro HTTP**: `POST /access-events/qr` responde `200` com `decision: DENIED` e o `reason` (ex.: `OUT_OF_RANGE`, `AUTHORIZATION_EXPIRED`), porque toda tentativa é registrada como evento.
- **Perfis**: `ADMIN` (administrador), `RESIDENT` (condômino), `VISITOR` (visitante).

## Como o contrato é mantido

O YAML **é gerado, não editado à mão**. A fonte única são os schemas Zod e a lista de operações em [`backend/src/main/http/contract/`](../../backend/src/main/http/contract/): deles saem as rotas stub, o `/openapi.json` e este arquivo.

Para mudar o contrato:

1. Edite os schemas (`contract/schemas/*.ts`) e/ou `contract/operations.ts`.
2. Rode `npm run openapi:generate` no `backend/`.
3. Commite o código **e** o `docs/api/openapi.yaml` juntos.

Requisições usam a forma de **entrada** dos schemas (antes de `transform`/`default`) e respostas a forma de **saída**. Quando as duas diferem, o componente de entrada mantém o nome (`X`) e o de saída ganha o sufixo `XOutput`; um schema usado só em respostas mantém o nome base. Objetos de resposta não são fechados (`additionalProperties`), para que acrescentar campo continue compatível.

O teste `tests/unit/openapi-document.test.ts` falha no CI se o YAML commitado estiver desatualizado, e também valida o documento contra a especificação OpenAPI 3.1.

**Contrato congelado**: depois do merge da US-06, mudança que quebra o app (remover/renomear campo ou rota, novo campo obrigatório na entrada, novo valor de enum na resposta) precisa ser combinada com o time mobile antes. Acrescentar campo opcional ou rota nova é compatível.
