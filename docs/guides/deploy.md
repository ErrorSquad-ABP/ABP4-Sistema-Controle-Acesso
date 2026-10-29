# Deploy do backend (Vercel + Neon)

A API roda na **Vercel** (Express serverless, zero-config) e o banco é o **Neon** (Postgres com pooler). O deploy é automático: todo merge na `main` que muda `backend/` dispara o [`cd-backend.yml`](../../.github/workflows/cd-backend.yml). Decisões e limites dos planos gratuitos em [`adr/001`](../architecture/adr/001-provisionamento-vercel-neon.md). O app Flutter **não** é publicado.

## Como funciona

```text
merge na main ─► cd-backend-check (npm ci · lint · typecheck · testes · build)
              └► cd-backend-deploy (vercel pull · build · migrate deploy · deploy --prod)
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
2. Em **Settings → Environment Variables** (ambiente **Production**): `DATABASE_URL` (a string do Neon), `JWT_SECRET` (32+ caracteres aleatórios), `QR_TOKEN_SECRET` (saída de `openssl rand -hex 32`), `TRUST_PROXY=1`, `NODE_ENV=production` e `LOG_LEVEL=info`.
   Configure o mesmo `QR_TOKEN_SECRET` no serviço MQTT/worker: ambos precisam assinar e validar com a mesma chave. Não use um valor de exemplo nem compartilhe a chave em logs.
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
| Secret | `PROD_MIGRATION_DATABASE_URL` | connection string **direta** do Neon (sem `-pooler`), só para migrations |

`PROD_MIGRATION_DATABASE_URL` é separada do `DATABASE_URL` da Vercel de propósito: migrations usam conexão direta e o job de deploy não deve depender dos arquivos internos da Vercel. O CD roda `prisma migrate deploy` **depois** do build e **antes** do deploy; migration com erro impede a promoção. Nenhuma seed roda em produção. A aplicação **não** tem rollback automático de banco: a migration precisa ser compatível com a versão anterior enquanto o deploy não termina.

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

## Orçamento de conexões (DT-14)

O DT-14 orça **conexões clientes**: quantas conexões cada processo abre para o endpoint `-pooler` do Neon. Isso **não** é o teto de conexões do projeto. Entre os clientes e o Postgres existe o PgBouncer do pooler, e o número de conexões reais ao compute é decidido por ele — depende do plano, do tamanho do compute e da configuração (não ajustável) do pooler.

Os limites ficam em [`connection-budget.ts`](../../backend/src/main/config/connection-budget.ts); cada pool tem um `application_name` para dar para medir.

### Conexões clientes por processo

| Processo | Fonte | Uso | Máx. clientes | `application_name` |
|---|---|---|---|---|
| API (por instância) | Prisma | usuários, autorizações, histórico | 3 | `abp4-api-prisma` |
| API (por instância) | pool de acesso | decisão QR e comandos | 3 | `abp4-api-access` |
| API (por instância) | probe | `/health` | 1 | `abp4-api-probe` |
| **API, total por instância** | | | **7** | |
| Worker (por réplica) | pool de acesso | decisão NFC, comandos e ACKs | 5 | `abp4-worker-access` |
| Worker (por réplica) | deduplicação | reserva das mensagens MQTT | 2 | `abp4-worker-events` |
| **Worker, total por réplica** | | | **7** | |

A deduplicação MQTT existe só no worker: a API não recebe mensagens do broker e não cria essa pool.

**Clientes abertos:** `7 × instâncias da API + 7 × réplicas do worker + 1 (migration do CD, conexão direta sem pooler)`. Hoje o worker roda em uma réplica, então o total é `7N + 8`.

Esse número é um orçamento **por instância/réplica**, não um teto global: cada instância fria da API que a Vercel sobe abre outros 7, e não há limite configurado no código para o total. O teto global de conexões ao Postgres é o `max_connections` do compute; o `default_pool_size` do pooler limita cada par usuário/banco, na tabela abaixo.

### Onde os 7 + 7 param (o teto real)

| Camada | Quem limita | Valor | Efeito ao estourar |
|---|---|---|---|
| Cliente → pooler | este orçamento | `7N + 8` conexões abertas | cada instância nova soma 7; não há teto global |
| Cliente → pooler | `max_client_conn` do PgBouncer | 10.000 (fixo) | "no more connections allowed" |
| Pooler → Postgres | `default_pool_size` do PgBouncer | 0,9 × `max_connections` do compute, **por par usuário/banco** | só aquele par espera na fila; não é um teto global de backends |
| Fila do pooler | `query_wait_timeout` | 120 s | erro `query_wait_timeout` depois de 2 min |
| Direto ao compute | `max_connections` | 104 (0,25 CU) a 4000 (9+ CU) | "remaining connection slots are reserved" |

Valores do pooler e de `max_connections` em [Connection pooling](https://neon.com/docs/connect/connection-pooling) e [Parameter settings by compute size](https://neon.com/docs/reference/compatibility); conferidos em 29/10/2026.

`default_pool_size` é o máximo de conexões de servidor **por par usuário/banco** no PgBouncer — não um orçamento global somado entre pares. O teto global de backends é o `max_connections` do compute; cada par adicional ganha o próprio `default_pool_size`. Como esta aplicação usa um único par (usuário e banco), o teto do par coincide, na prática, com o teto do nosso tráfego — é essa a premissa do cenário abaixo, não uma soma de 0,9 × `max_connections` por cliente.

`max_connections` segue a fórmula `max(100, min(4000, floor(CU × 419,66)))`; sete conexões ficam reservadas para o superusuário do Neon. Com o autoscaling padrão do plano free (0,25 a 2 CU), o valor efetivo é o do topo da faixa: `min(2, 8 × 0,25) = 2 CU` → 839.

### Cenário de envelope (estimativa)

Premissas, todas estimadas: compute fixo no tamanho indicado; um único par usuário/banco (o de hoje), então o `default_pool_size = 0,9 × max_connections` vale como teto do nosso tráfego — outro par teria o próprio teto; pico de consultas simultâneas ≈ `7N + 2` (7 por instância da API e 2 decisões NFC no worker); 1 conexão da migration; folga desejada de pelo menos 20% do teto do par.

| Cenário | `max_connections` | Teto do par (0,9×) | Clientes abertos (`7N + 8`) | Pico de consultas (`7N + 2`) | Folga vs. teto do par | Leitura |
|---|---|---|---|---|---|---|
| 0,25 CU, N = 1 | 104 | 93 | 15 | 9 | 84 | folgado |
| 0,25 CU, N = 5 | 104 | 93 | 43 | 37 | 56 | ok |
| 0,25 CU, N = 10 | 104 | 93 | 78 | 72 | 21 | encosta no limite (20% de folga = ~74) |
| 0,5 CU, N = 10 | 209 | 188 | 78 | 72 | 116 | folgado |
| 1 CU, N = 25 | 419 | 377 | 183 | 177 | 200 | folgado |

Envelope admissível, em uma frase: o `max_client_conn` do pooler (10.000) não é o gargalo; com um único par usuário/banco, o gargalo é o `default_pool_size` desse par (limitado também pelo `max_connections`). O pico de consultas simultâneas precisa ficar abaixo de `0,9 × max_connections` com margem — na prática, com 0,25 CU, até ~10 instâncias da API; acima disso, aumente o compute ou reduza o `max` das pools. Com mais de um par, cada par tem o próprio teto e a conta deixa de ser a desta tabela.

O que é estimativa nesta seção: o `default_pool_size` como teto do nosso par, o pico de consultas simultâneas e a folga de 20%. O que é documentado pelo Neon: `max_client_conn = 10.000`, `query_wait_timeout = 120 s`, `default_pool_size = 0,9 × max_connections` por par usuário/banco e a tabela de `max_connections`.

### Concorrência e tempo de espera por instância da API

- até 3 decisões QR e 3 consultas Prisma ao mesmo tempo;
- o excedente espera uma conexão livre por até 5 s (`POOL_CONNECTION_TIMEOUT_MS`) e depois falha;
- uma consulta já enviada tem teto de 4 s no cliente (`POOL_QUERY_TIMEOUT_MS`, `query_timeout` do `pg`), inclusive nas consultas do Prisma via driver adapter. O teto é **por consulta**, não por pedido: um pedido que espera até 5 s por uma conexão livre e encadeia várias consultas soma esses tempos e pode passar de 4 s. Esse teto libera quem espera, mas **não cancela a consulta no servidor**: ela pode continuar na fila do pooler até o `query_wait_timeout` de 120 s. Não usamos `statement_timeout` no startup porque o pooler do Neon recusa parâmetros de startup fora da lista permitida (`client_encoding`, `datestyle`, `timezone`, `standard_conforming_strings`, `application_name`) — ver [Connection errors](https://neon.com/docs/connect/connection-errors). Para um teto no servidor seria preciso `ALTER ROLE ... SET statement_timeout`, que vale para todos os clientes (inclusive migrations) e não foi aplicado;
- mais tráfego simultâneo escala em instâncias novas da Vercel, cada uma somando mais 7 conexões clientes.

O worker decide até 2 NFC em paralelo, limitado pela pool da deduplicação, e não disputa conexões com a API.

### O que ainda não foi verificado

- **Neon real:** nenhuma medição no projeto de produção. Os números de compute, `max_connections` e pooler acima vêm da documentação do Neon e de contas, não de observação; a conferência abaixo precisa ser feita com o deploy no ar.
- **Múltiplas instâncias da Vercel:** o E2E roda uma única instância da API e um único worker. A multiplicação por instâncias frias é comportamento esperado da plataforma, não medido.
- **Teto no servidor:** o `query_timeout` é do cliente; o cancelamento server-side (`statement_timeout` por role) não está configurado nem testado.

Para conferir em produção:

```sql
SELECT application_name, state, count(*) FROM pg_stat_activity
WHERE application_name LIKE 'abp4-%' GROUP BY 1, 2 ORDER BY 1;
```

O E2E `DT-14` dispara uma rajada concorrente contra a API, mede o `pg_stat_activity` e falha se alguma fonte passar do limite ou se o NFC do worker atrasar. Ele mede o tempo só do ramo MQTT (evento → ACK), então um HTTP lento não contamina a medição.

## Rollback

No painel da Vercel use **Instant Rollback** no deploy anterior, ou reverta o commit na `main` e deixe o CD publicar de novo.

## Worker MQTT no Render (US-37)

A API é serverless e não mantém conexão MQTT aberta; quem assina os tópicos do terminal é um **web service** no Render (`backend/src/main/worker.ts`), com URL própria e o mesmo broker MQTT. No modo real (`ACCESS_MODE=real`) o worker também acessa o Neon: decide os acessos NFC, deduplica as mensagens e correlaciona os ACKs. As conexões que ele usa estão em [Orçamento de conexões](#orçamento-de-conexões-dt-14).

1. No Render: **New → Blueprint** e aponte para o repositório (o `render.yaml` é lido da raiz). O serviço `abp4-mqtt-worker` usa `rootDir: backend`, build `npm ci && npm run build` e start `node dist/main/worker.js`.
2. Em **Environment**, preencha `MQTT_URL` (`mqtts://<host>:8883` do HiveMQ), `MQTT_USERNAME` e `MQTT_PASSWORD`. O `PORT` é injetado pelo Render.
3. Copie a URL pública do serviço (ex.: `https://abp4-mqtt-worker.onrender.com`) para `RENDER_EXTERNAL_URL`. É ela que liga o **self-ping a cada 10 min** em `/healthz`, evitando o spin-down de 15 min do plano free.
4. Confira em **Logs** a linha `mqtt conectado` e, no HiveMQ, o cliente `abp4-consumer-<pid>`.

O worker **não** roda migrations nem a seed: migrations rodam no `cd-backend.yml` e a seed é só de desenvolvimento, nunca em produção. Se o processo cair, o Render reinicia e o `mqtt.js` reconecta sozinho; comandos pendentes vivem em memória (limitação registrada na DT-02). O decisor de acesso segue provisório (DT-01), então liberar acesso via MQTT hoje não é seguro fora de demonstração.
