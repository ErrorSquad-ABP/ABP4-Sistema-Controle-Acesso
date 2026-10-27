# backend

API REST do Sistema de Controle de Acesso — Node 24 + Express 5 + TypeScript, em clean architecture pragmática (US-03).

## Camadas

```text
src/
├─ domain/          entidades, erros de domínio e ports (interfaces) — sem dependências externas
├─ application/     casos de uso (importam só domain)
├─ infrastructure/  adapters que implementam os ports (relógio, ids, mqtt.js e parser de payloads; Prisma)
├─ main/            env.ts, app Express, rotas, middlewares, composition roots, server, consumidor MQTT e simulador
│  └─ http/contract/ contrato REST v1: schemas Zod + operations.ts → rotas e OpenAPI (US-06)
└─ shared/          utilitários sem regra de negócio (logger, hash de senha)
prisma/              schema.prisma · migrations · seed.ts
scripts/             generate-openapi.ts (gera docs/api/openapi.yaml)
tests/
├─ unit/            casos de uso, env, schemas do contrato e documento OpenAPI (sem HTTP)
├─ integration/     rotas via Supertest em createApp()
└─ e2e/             HTTP/TCP, PostgreSQL temporario, MQTT e processos independentes
```

A regra de dependência entre camadas é verificada pelo ESLint. Para adicionar uma funcionalidade, siga o **[caso de uso modelo](../docs/architecture/caso-de-uso-modelo.md)**.

## Rodando

```bash
cd backend
cp .env.example .env     # opcional: sem .env valem os defaults
npm ci
npm run db:generate      # gera o Prisma Client em src/generated/prisma
npm run db:migrate:deploy  # aplica a migration no Postgres do compose
npm run db:seed          # dados de demonstração (idempotente)
npm run dev              # http://localhost:3000/health
```

O Postgres de dev sobe pelo compose (`docker compose -f infra/docker-compose.dev.yml up -d postgres`) e a `DATABASE_URL` do `.env.example` já aponta para ele. Sem banco, a API sobe e o `/health` responde `database: not_configured`.

| Script | O que faz |
|---|---|
| `npm run dev` | servidor com reload (tsx watch), lê `.env` se existir |
| `npm run build` | compila para `dist/` |
| `npm start` | roda o build (`node dist/main/server.js`) |
| `npm run db:generate` | gera o Prisma Client (necessário após `npm ci` e ao mudar o schema) |
| `npm run db:migrate` | cria/aplica migration em desenvolvimento (`prisma migrate dev`) |
| `npm run db:migrate:deploy` | aplica migrations pendentes (CI e produção) |
| `npm run db:seed` | popula os dados de demonstração (pode rodar de novo) |
| `npm run lint` | ESLint, incluindo a regra de camadas |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest (unit + integração) |
| `npm run test:coverage` | testes com cobertura |
| `npm run test:e2e` | build + E2E com PostgreSQL temporário, Aedes e terminal simulado; sem Docker/admin |
| `npm run openapi:generate` | regera `docs/api/openapi.yaml` a partir do contrato em `src/main/http/contract/` |
| `npm run mqtt:consumer` | consumidor MQTT local: assina os tópicos dos terminais, loga e responde com comando (US-04) |
| `npm run sim:terminal` | simulador de terminal: publica uma leitura NFC e responde o comando com ACK (`-- --keep-alive` mantém ativo) |

## Variáveis de ambiente

Validadas em [`src/main/config/env.ts`](src/main/config/env.ts); modelo em [`.env.example`](.env.example). Valor inválido derruba o boot com mensagem indicando a variável.

| Variável | Default | Descrição |
|---|---|---|
| `NODE_ENV` | `development` | `development` \| `test` \| `production` |
| `ACCESS_MODE` | `real` | consumidor exige decisor real e banco migrado; `demo` libera qualquer UID e é proibido em produção |
| `JWT_SECRET` | — | segredo HS256 com 32+ caracteres; junto com banco habilita QR e histórico autenticados |
| `PORT` | `3000` | porta HTTP |
| `LOG_LEVEL` | `info` | `fatal` \| `error` \| `warn` \| `info` \| `debug` \| `trace` \| `silent` |
| `APP_VERSION` | `dev` | versão exibida no `/health` (no CI/CD, o SHA do commit) |
| `DATABASE_URL` | — | Postgres (`postgres://` ou `postgresql://`); compose no dev, Neon com `-pooler` em produção. Sem ela o `/health` informa `not_configured` |
| `MQTT_URL` | `mqtt://localhost:1884` | broker MQTT (`mqtt://` ou `mqtts://`); dev = Mosquitto do compose |
| `MQTT_USERNAME` / `MQTT_PASSWORD` | — | credenciais do broker (HiveMQ Cloud em produção; vazias no dev) |
| `SIM_TERMINAL_ID` | `terminal-01` | id do terminal simulado |
| `SIM_NFC_UID` | `04A1B2C3` | UID NFC que o simulador lê |

## Endpoints

- `GET /health` → `200 { status, version, uptimeSeconds, timestamp, database }`. `database` é `ok`, `not_configured` (sem `DATABASE_URL`) ou `unavailable`; neste último caso a resposta é `503` com `status: "error"` (o motivo fica só no log).
- `GET /docs` → Swagger UI do contrato v1 · `GET /openapi.json` → o documento OpenAPI
- Com `DATABASE_URL` e `JWT_SECRET`, `POST /api/v1/access-events/qr`, `GET /api/v1/access-events` (ADMIN) e `GET /api/v1/me/access-events` usam banco e identidade reais. JWT exige `HS256`, `iss=abp4`, `aud=abp4-api`, `sub` UUID, `iat` e `exp`, idade máxima de uma hora. Perfil e situação ativa vêm do banco.
- As demais rotas continuam stubs `501 NOT_IMPLEMENTED`, incluindo login (US-14). Sem essas configurações, as três rotas de acesso também permanecem em stub. Detalhes em [`docs/api/README.md`](../docs/api/README.md).

## Segurança do consumidor (DT-01/02/03)

No modo padrão `real`, o consumidor valida o decisor e as tabelas antes de conectar ao broker. Cada `Terminal.id` corresponde ao identificador MQTT e deve estar vinculado a um `AccessLocation`. A seed cadastra `terminal-01` no local demo e a tag `04A1B2C3`; ela é somente para desenvolvimento.

API e worker usam o mesmo `DATABASE_URL`. `TerminalCommand` persiste o comando antes do envio e correlaciona o ACK por `commandId` + terminal mesmo após reinício. Repetições preservam identificador e expiração; ACK repetido não altera o resultado. Falha de publicação não apaga o registro, pois a entrega pode ter ocorrido.

O decisor real valida terminal/local ativos, credencial, usuário, autorização do local, janela e usos. QR também valida token opaco de 256 bits vinculado ao terminal, validade de 10 s e geofence do local. O banco guarda somente seu hash. Consumo de uso e evento são gravados na mesma transação. Negativas por terminal desconhecido ficam consultáveis com `location: null` e o `terminalId` recebido.

Para a demonstração antiga de transporte, configure explicitamente `ACCESS_MODE=demo` e `NODE_ENV=development`. Esse modo registra aviso e usa comandos em memória; não demonstra autorização real.

`npm run test:e2e` cria seu próprio PostgreSQL e broker em portas locais livres, aplica migrations, compara schema, executa seed duas vezes e inicia API/worker compilados em processos distintos. O terminal usa o simulador do projeto. Dados ficam em diretório temporário exclusivo, removido ao terminar; não acessa o banco do `.env` e não requer Docker, serviço do Windows ou administrador. Na primeira instalação, o npm baixa os binários da plataforma. Linux precisa executar com usuário comum, como o runner do GitHub Actions.

Roteiro e limites em [`dt-01-02-03.md`](../docs/entrega/evidencias/dt-01-02-03.md).

Erros seguem sempre `{ "error": { "code", "message", "details?" } }` — tabela completa no guia do caso de uso modelo.

## Deploy

O deploy na Vercel é automático após o merge na `main` (`cd-backend.yml`); a entrada serverless é `src/index.ts`. Configuração e rollback em [`docs/guides/deploy.md`](../docs/guides/deploy.md).

## Docker

```bash
cd backend
docker build -t abp4-backend .
docker run --rm -p 3000:3000 abp4-backend
```

Imagem multi-stage `node:24-alpine`, roda como usuário `node` com só as dependências de produção e tem `HEALTHCHECK` no `/health`.
