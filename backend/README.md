# backend

API REST do Sistema de Controle de Acesso — Node 24 + Express 5 + TypeScript, em clean architecture pragmática (US-03).

## Camadas

```text
src/
├─ domain/          entidades, erros de domínio e ports (interfaces) — sem dependências externas
├─ application/     casos de uso (importam só domain)
├─ infrastructure/  adapters que implementam os ports (relógio hoje; Prisma/MQTT nos próximos cards)
├─ main/            env.ts, app Express, rotas, middlewares, composition root e server
└─ shared/          utilitários sem regra de negócio (logger)
tests/
├─ unit/            casos de uso e env, sem HTTP
└─ integration/     rotas via Supertest em createApp()
```

A regra de dependência entre camadas é verificada pelo ESLint. Para adicionar uma funcionalidade, siga o **[caso de uso modelo](../docs/architecture/caso-de-uso-modelo.md)**.

## Rodando

```bash
cd backend
cp .env.example .env     # opcional: sem .env valem os defaults
npm ci
npm run dev              # http://localhost:3000/health
```

| Script | O que faz |
|---|---|
| `npm run dev` | servidor com reload (tsx watch), lê `.env` se existir |
| `npm run build` | compila para `dist/` |
| `npm start` | roda o build (`node dist/main/server.js`) |
| `npm run lint` | ESLint, incluindo a regra de camadas |
| `npm run typecheck` | `tsc --noEmit` |
| `npm test` | Vitest (unit + integração) |
| `npm run test:coverage` | testes com cobertura |

## Variáveis de ambiente

Validadas em [`src/main/config/env.ts`](src/main/config/env.ts); modelo em [`.env.example`](.env.example). Valor inválido derruba o boot com mensagem indicando a variável.

| Variável | Default | Descrição |
|---|---|---|
| `NODE_ENV` | `development` | `development` \| `test` \| `production` |
| `PORT` | `3000` | porta HTTP |
| `LOG_LEVEL` | `info` | `fatal` \| `error` \| `warn` \| `info` \| `debug` \| `trace` \| `silent` |
| `APP_VERSION` | `dev` | versão exibida no `/health` (no CI/CD, o SHA do commit) |

## Endpoints

- `GET /health` → `200 { status, version, uptimeSeconds, timestamp }`

Erros seguem sempre `{ "error": { "code", "message", "details?" } }` — tabela completa no guia do caso de uso modelo.

## Docker

```bash
cd backend
docker build -t abp4-backend .
docker run --rm -p 3000:3000 abp4-backend
```

Imagem multi-stage `node:24-alpine`, roda como usuário `node` com só as dependências de produção e tem `HEALTHCHECK` no `/health`.
