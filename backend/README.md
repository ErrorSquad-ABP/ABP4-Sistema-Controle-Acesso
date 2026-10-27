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
└─ integration/     rotas via Supertest em createApp()
```

A regra de dependência entre camadas é verificada pelo ESLint. Para adicionar uma funcionalidade, siga o **[caso de uso modelo](../docs/architecture/caso-de-uso-modelo.md)**.

## Rodando

```bash
cd backend
cp .env.example .env     # opcional: sem .env valem os defaults
npm ci
npm run db:generate      # gera o Prisma Client em src/generated/prisma
npm run db:migrate:deploy  # aplica a migration no Postgres do compose
npm run db:seed          # dados de demonstração (idempotente; só banco local)
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
| `npm run db:seed` | popula os dados de **demonstração** (pode rodar de novo). Recusa `NODE_ENV`/`VERCEL_ENV=production` e banco que não seja local, salvo `ALLOW_DEMO_SEED=true` em banco descartável |
| `npm run db:provision` | cria o primeiro administrador **real** a partir de `ADMIN_EMAIL`/`ADMIN_PASSWORD` (`ADMIN_NAME` opcional); roda em produção, não grava dados de demonstração e não altera conta que já existe |
| `npm run lint` | ESLint, incluindo a regra de camadas |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest (unit + integração) |
| `npm run test:coverage` | testes com cobertura |
| `npm run openapi:generate` | regera `docs/api/openapi.yaml` a partir do contrato em `src/main/http/contract/` |
| `npm run mqtt:consumer` | consumidor MQTT local: assina os tópicos dos terminais, loga e responde com comando (US-04) |
| `npm run sim:terminal` | simulador de terminal: publica uma leitura NFC e responde o comando com ACK (`-- --keep-alive` mantém ativo) |

## Variáveis de ambiente

Validadas em [`src/main/config/env.ts`](src/main/config/env.ts); modelo em [`.env.example`](.env.example). Valor inválido derruba o boot com mensagem indicando a variável.

| Variável | Default | Descrição |
|---|---|---|
| `NODE_ENV` | `development` | `development` \| `test` \| `production` |
| `PORT` | `3000` | porta HTTP |
| `LOG_LEVEL` | `info` | `fatal` \| `error` \| `warn` \| `info` \| `debug` \| `trace` \| `silent` |
| `APP_VERSION` | `dev` | versão exibida no `/health` (no CI/CD, o SHA do commit) |
| `DATABASE_URL` | — | Postgres (`postgres://` ou `postgresql://`); compose no dev, Neon com `-pooler` em produção. Sem ela o `/health` informa `not_configured` |
| `ALLOW_DEMO_SEED` | — | `true` libera a seed demo em banco remoto descartável; nunca vale em produção |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` / `ADMIN_NAME` | — | só para `db:provision`: e-mail (fora de `@abp4.local`), senha com 12+ caracteres e nome do primeiro administrador |
| `MQTT_URL` | `mqtt://localhost:1884` | broker MQTT (`mqtt://` ou `mqtts://`); dev = Mosquitto do compose |
| `MQTT_USERNAME` / `MQTT_PASSWORD` | — | credenciais do broker (HiveMQ Cloud em produção; vazias no dev) |
| `QR_TOKEN_SECRET` | obrigatório | 32 bytes aleatórios em hexadecimal, iguais nos processos HTTP e MQTT; gere com `openssl rand -hex 32` |
| `SIM_TERMINAL_ID` | `terminal-01` | id do terminal simulado |
| `SIM_NFC_UID` | `04A1B2C3` | UID NFC que o simulador lê |

## Endpoints

- `GET /health` → `200 { status, version, uptimeSeconds, timestamp, database }`. `database` é `ok`, `not_configured` (sem `DATABASE_URL`) ou `unavailable`; neste último caso a resposta é `503` com `status: "error"` (o motivo fica só no log).
- `GET /docs` → Swagger UI do contrato v1 · `GET /openapi.json` → o documento OpenAPI
- `POST /api/v1/credentials/qr/validate` → operação autenticada do contrato v1 para validar assinatura, terminal e validade de 10 s. A rota protegida depende do middleware JWT da US-14; até lá, segue como stub `501` após validar a entrada. O caso de uso criptográfico está implementado e testado. Não decide acesso nem registra eventos.
- `/api/v1/...` → rotas do contrato v1 (auth, users, authorizations, access-events). Por enquanto são stubs: validam a entrada com Zod e respondem `501 NOT_IMPLEMENTED` citando o card que as implementa. Detalhes em [`docs/api/README.md`](../docs/api/README.md).

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
