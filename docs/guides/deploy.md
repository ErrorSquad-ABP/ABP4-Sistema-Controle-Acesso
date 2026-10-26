# Deploy do backend (Vercel + Neon)

A API roda na **Vercel** (Express serverless, zero-config) e o banco é o **Neon** (Postgres com pooler). O deploy é automático: todo merge na `main` que muda `backend/` dispara o [`cd-backend.yml`](../../.github/workflows/cd-backend.yml). Decisões e limites dos planos gratuitos em [`adr/001`](../architecture/adr/001-provisionamento-vercel-neon.md). O app Flutter **não** é publicado.

## Como funciona

```text
merge na main ─► cd-backend-check (npm ci · lint · typecheck · testes · build)
              └► cd-backend-deploy (vercel pull · build · deploy --prebuilt --prod)
                                   └► smoke test: GET /health → status ok · database ok · versão = SHA do commit
```

- A entrada serverless é [`backend/src/index.ts`](../../backend/src/index.ts) (exporta o app Express). Local e Docker continuam usando `src/main/server.ts`.
- O deploy é feito **só pelo workflow** (Vercel CLI). O deploy automático do Git na Vercel deve ficar desligado, para não haver dois caminhos.
- `APP_VERSION` recebe o SHA curto do commit: o `/health` mostra qual versão está no ar.
- O smoke test falha o job se o `/health` não responder `status: ok`, `database: ok` e a versão esperada em até ~100 s.
- O smoke test roda **depois** do deploy de produção: o domínio já aponta para a versão nova quando ele começa. Um smoke vermelho deixa o job vermelho, mas **não desfaz o deploy** — a correção é o rollback manual (seção abaixo) ou um novo merge. Fazer o teste valer como gate exigiria deploy de preview + `vercel promote`, e a URL de preview exige proteção da Vercel; ficou para quando houver `VERCEL_AUTOMATION_BYPASS_SECRET`.
- Dispare manualmente, se precisar, em **Actions → cd-backend → Run workflow** na branch `main`. Em outra branch só o `cd-backend-check` roda: produção nunca recebe código que não esteja na `main`.

## Configuração única (manual)

Ninguém precisa colar credenciais no repositório nem no chat. Cada item abaixo é feito nos painéis dos serviços.

### 1) Neon

1. Crie o projeto (região próxima da região das funções da Vercel).
2. Em **Connect**, copie a connection string com o endpoint **`-pooler`** (obrigatório em serverless), formato `postgresql://usuario:senha@ep-...-pooler....neon.tech/banco?sslmode=require`.
3. Teste a conexão: `psql "<connection string>" -c "select 1"`.

### 2) Vercel

1. **New Project** → importe o repositório → **Root Directory: `backend`** → **Application Preset: Express** (não use "Container").
2. Em **Settings → Environment Variables** (ambiente **Production**): `DATABASE_URL` (a string do Neon), `JWT_SECRET` (32+ caracteres aleatórios), `NODE_ENV=production` e `LOG_LEVEL=info`.
3. Em **Settings → Git**, desconecte o repositório (ou desligue os deploys automáticos): o CD é o `cd-backend.yml`.
4. Anote o **Project ID** (Settings → General) e o **Team/Org ID** (Settings do time).
5. Gere um token em [vercel.com/account/tokens](https://vercel.com/account/tokens).
6. O domínio de produção (`<projeto>.vercel.app`) é público; a URL única de cada deploy pode exigir login da Vercel, por isso o smoke test usa o domínio de produção.

### 3) GitHub (Settings → Secrets and variables → Actions)

| Tipo | Nome | Valor |
|---|---|---|
| Secret | `VERCEL_TOKEN` | token da Vercel |
| Variable | `VERCEL_ORG_ID` | Team/Org ID da Vercel |
| Variable | `VERCEL_PROJECT_ID` | Project ID da Vercel |
| Variable | `BACKEND_URL` | domínio público de produção, ex.: `https://abp-4-sistema-controle-acesso.vercel.app` |

Sem `BACKEND_URL` o smoke test usa a URL do deploy, que pode ser bloqueada pela proteção da Vercel.

## Conferindo

```bash
curl -i https://<dominio-de-producao>/health
```

Esperado: `200` com `{"status":"ok","version":"<sha>","database":"ok",...}`. Se o banco estiver configurado mas fora do ar, a resposta é `503` com `"database":"unavailable"` (o motivo fica só nos logs da Vercel, nunca na resposta).

## Problemas comuns

| Sintoma | Causa provável |
|---|---|
| `::error::VERCEL_TOKEN nao configurado` | secret/variáveis do GitHub ausentes (seção 3) |
| `/health` com `database: not_configured` em produção | `DATABASE_URL` não está no ambiente Production da Vercel |
| `/health` com `503` / `unavailable` | connection string errada, sem `-pooler`, ou Neon suspenso (a primeira consulta após ocioso leva ~1 s; o smoke test repete) |
| Smoke test falha por versão diferente | o domínio de produção ainda aponta para o deploy anterior; confira o último deploy no painel |
| Deploy duplicado | deploy do Git ainda ligado na Vercel (seção 2, item 3) |

## Rollback

No painel da Vercel use **Instant Rollback** no deploy anterior, ou reverta o commit na `main` e deixe o CD publicar de novo.

## Worker MQTT no Render (US-37)

A API é serverless e não mantém conexão MQTT aberta; quem assina os tópicos do terminal é um **web service** no Render (`backend/src/main/worker.ts`), com URL própria e o mesmo broker/Neon. O `render.yaml` na raiz descreve o serviço.

1. No Render: **New → Blueprint** e aponte para o repositório (o `render.yaml` é lido da raiz). O serviço `abp4-mqtt-worker` usa `rootDir: backend`, build `npm ci && npm run build` e start `node dist/main/worker.js`.
2. Em **Environment**, preencha `MQTT_URL` (`mqtts://<host>:8883` do HiveMQ), `MQTT_USERNAME` e `MQTT_PASSWORD`. O `PORT` é injetado pelo Render.
3. Copie a URL pública do serviço (ex.: `https://abp4-mqtt-worker.onrender.com`) para `RENDER_EXTERNAL_URL`. É ela que liga o **self-ping a cada 10 min** em `/healthz`, evitando o spin-down de 15 min do plano free.
4. Confira em **Logs** a linha `mqtt conectado` e, no HiveMQ, o cliente `abp4-consumer-<pid>`.

O worker **não** roda migrations nem a seed: isso continua no `cd-backend.yml`/Neon. Se o processo cair, o Render reinicia e o `mqtt.js` reconecta sozinho; comandos pendentes vivem em memória (limitação registrada na DT-02).
