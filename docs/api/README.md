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

**Todas as rotas do contrato v1 têm implementação**: `POST /auth/login`, `GET /auth/me`, o CRUD de usuários (`GET`/`POST /users`, `GET`/`PATCH`/`DELETE /users/{id}`), `GET /me/authorizations`, as quatro rotas administrativas de autorizações (`GET`/`POST /authorizations`, `GET /authorizations/{id}`, `POST /authorizations/{id}/cancel`), `POST /credentials/qr/validate` e as três rotas de `access-events` (`POST /access-events/qr` exige `DATABASE_URL`). Só o login é público; as demais exigem identidade real, e `users`, a listagem global de eventos e as rotas administrativas de autorizações exigem ADMIN. O roteador stub ([`api-v1.routes.ts`](../../backend/src/main/http/routes/api-v1.routes.ts)) segue montado como rede de segurança para operação nova do contrato sem caso de uso, mas hoje nenhuma operação cai nele: não há rota respondendo `501`.

## Convenções

- **Autenticação**: `Authorization: Bearer <accessToken>` de `POST /auth/login`. O token é HS256 com `JWT_SECRET`, `iss=abp4`, `aud=abp4-api`, `sub` UUID, `iat` e `exp`. Perfil e situação ativa são consultados no banco, nunca confiados ao claim do token.
- **Datas**: ISO 8601. Na entrada aceita offset (`2026-10-20T14:00:00-03:00`); na resposta sempre UTC (`Z`).
- **Erros**: `{ "error": { "code", "message", "details?" } }` — tabela de códigos em [`caso-de-uso-modelo.md`](../architecture/caso-de-uso-modelo.md#erros-do-domínio-ao-http). Banco não configurado nas rotas de auth/usuários/autorizações/histórico → `503 SERVICE_UNAVAILABLE`; excesso de requisições → `429 TOO_MANY_REQUESTS`.
- **Usuários**: e-mail normalizado para minúsculas e único (`409 CONFLICT` se já existir); senha guardada como hash scrypt com salt aleatório e nunca devolvida. `DELETE /users/{id}` é exclusão lógica (`active=false`): o histórico de acessos fica preservado.
- **Minhas autorizações**: o `userId` vem do token, nunca da query. `status` filtra a situação calculada — `CANCELED` (cancelada), `SCHEDULED` (antes do início), `EXPIRED` (fim alcançado ou usos esgotados) e `ACTIVE`; `remainingUses = max(0, maxUses - usedCount)`; ordem `startsAt desc, id desc`.
- **Listas**: `{ items, page, pageSize, total }`; `page` começa em 1, `pageSize` padrão 20 (máx. 100).
- **Pedido de acesso QR**: o app envia `qrToken` (lido do QR), `terminalId`, `position` e, opcionalmente, `requestId`. O usuário vem do JWT. O token é o assinado da US-19 (`v1.<terminal>.<iat>.<exp>.<hmac>`, validade de 10 s); divergência de terminal ou assinatura nega com `INVALID_CREDENTIAL`, e token vencido com `CREDENTIAL_EXPIRED`. Geofence usa as coordenadas e o raio do local mapeado.
- **Idempotência do pedido**: repetir o mesmo `requestId` devolve o mesmo evento e o mesmo comando, sem consumir a autorização de novo e sem esticar o prazo do comando.
- **Terminal desconhecido**: nega com `UNKNOWN_TERMINAL`, preserva o identificador em `event.terminalId` e retorna `event.location: null`. Terminal ou local desativado nega com `TERMINAL_INACTIVE`. Eventos legados podem ter `terminalId: null`.
- **Acesso negado não é erro HTTP**: `POST /access-events/qr` responde `200` com `decision: DENIED` e o `reason` (ex.: `OUT_OF_RANGE`, `AUTHORIZATION_EXPIRED`), porque toda tentativa é registrada como evento.
- **Perfis**: `ADMIN` (administrador), `RESIDENT` (condômino), `VISITOR` (visitante).

## CORS

O app web (Flutter Web) chama a API de outra origem, e o navegador só deixa o app ler a resposta se a API a autorizar (DT-08). A API responde CORS por **allowlist exata**, configurada em `CORS_ALLOWED_ORIGINS` (lista separada por vírgula, validada no boot):

| Origem | Quando |
|---|---|
| `http://localhost:5000` | desenvolvimento: `flutter run -d chrome --web-port 5000` contra a API local (`CORS_ALLOWED_ORIGINS=http://localhost:5000`) |
| `https://<demo-web>.vercel.app` | demo web da US-38; o domínio entra aqui e na variável da Vercel quando for definido |
| _(nenhuma)_ | app Android (não envia `Origin`) e o Swagger em `/docs` (mesma origem) não precisam de CORS |

Regras:

- **Padrão vazio = CORS desligado.** Em produção a variável fica na Vercel (Settings → Environment Variables, ambiente Production), não no GitHub.
- Cada item é **exatamente uma origem** (`esquema://host[:porta]`): sem `*`, sem regex, sem barra final nem caminho, sem `null`. `http://` só vale para `localhost`, `127.0.0.1` e `[::1]`; as demais exigem `https://`. Valor inválido derruba o boot citando a variável.
- **Preflight** (`OPTIONS` com `Origin` e `Access-Control-Request-Method`) de origem permitida: `204` com `Access-Control-Allow-Origin` igual à origem que chamou (nunca `*` nem a lista), `Allow-Methods: GET, POST, PATCH, DELETE, OPTIONS`, `Allow-Headers: Authorization, Content-Type` e `Max-Age: 600`. De origem fora da lista: `204` sem nenhum cabeçalho de permissão, e o navegador bloqueia.
- O cabeçalho `Access-Control-Allow-Origin` vai em **toda** resposta à origem permitida, inclusive `4xx`, `429` e `5xx`, para o app conseguir ler o erro. `Vary: Origin` acompanha qualquer resposta a uma requisição com `Origin`.
- Sem `Allow-Credentials`: a autenticação é `Authorization: Bearer`, não cookie. O preflight não conta no limite de login.
- **Valor inválido derruba o boot, inclusive na Vercel**, onde isso deixa a API inteira fora do ar. Confira a lista antes de salvar a variável; o comando está em [`deploy.md`](../guides/deploy.md#2-vercel).
- **CORS não é autenticação.** Ele só controla o que o navegador deixa o app ler: uma origem fora da lista ainda consegue enviar a requisição ao servidor. A proteção real continua sendo o JWT, o perfil e o rate limit.

## Como o contrato é mantido

O YAML **é gerado, não editado à mão**. A fonte única são os schemas Zod e a lista de operações em [`backend/src/main/http/contract/`](../../backend/src/main/http/contract/): deles saem as rotas stub, o `/openapi.json` e este arquivo.

Para mudar o contrato:

1. Edite os schemas (`contract/schemas/*.ts`) e/ou `contract/operations.ts`.
2. Rode `npm run openapi:generate` no `backend/`.
3. Commite o código **e** o `docs/api/openapi.yaml` juntos.

Requisições usam a forma de **entrada** dos schemas (antes de `transform`/`default`) e respostas a forma de **saída**. Quando as duas diferem, o componente de entrada mantém o nome (`X`) e o de saída ganha o sufixo `XOutput`; um schema usado só em respostas mantém o nome base. Objetos de resposta não são fechados (`additionalProperties`), para que acrescentar campo continue compatível.

O teste `tests/unit/openapi-document.test.ts` falha no CI se o YAML commitado estiver desatualizado, e também valida o documento contra a especificação OpenAPI 3.1.

**Contrato congelado**: depois do merge da US-06, mudança que quebra o app (remover/renomear campo ou rota, novo campo obrigatório na entrada, novo valor de enum na resposta) precisa ser combinada com o time mobile antes. Acrescentar campo opcional ou rota nova é compatível.

DT-03 amplia a resposta para negativas sem local: `location` agora aceita `null`, `terminalId` foi acrescentado e há dois motivos novos. O mobile atual ainda não implementa o consumo desse histórico; a integração futura deve tratar esses casos. O OpenAPI versionado e seus testes refletem essa alteração.
