# ADR 001 — Provisionamento: Vercel (API) + Neon (Postgres) + HiveMQ (MQTT)

- **Data**: 16/10/2026 · **Status**: aceita

## Contexto

RNF06 exige banco em nuvem; RP11 pede deploy automatizado; RP12 pede containers no dev. O time decidiu usar a **Vercel** para a API (back) e o **Neon** para o banco (Postgres), aproveitando a infra e o suporte dos dois serviços no tier gratuito.

## Decisão

- **API (Node + Express + TypeScript)**: **Vercel**, rodando como serverless function (Express adaptado em `api/index.ts`).
- **Banco**: **Neon** (Postgres serverless, com **pooling** — a `DATABASE_URL` usa o endpoint `-pooler`, necessário em ambiente serverless).
- **Broker MQTT**: **HiveMQ Cloud** (TLS + credenciais) como canal IoT.
- O app (front) é **Flutter mobile** e não é hospedado na Vercel; um build web do Flutter pode ser publicado como demo, se o time quiser.

## Consequências

- A Vercel é **serverless**: não mantém processos de longa duração. Um cliente MQTT "sempre ligado" **não roda lá**. Por isso:
  - **Terminal → backend**: HTTP(S) direto do ESP32 (busca do QR a cada 10s, envio de leituras NFC, heartbeat).
  - **Backend → terminal**: publicação MQTT **pontual** por comando (conecta → publica → desconecta), o que é seguro em serverless.
  - O **worker MQTT persistente** (conexão sempre ativa: assina os tópicos do terminal e publica comandos) roda no **Render** como web service pequeno — mesmo repositório da API, com entry point próprio (`worker.ts`), URL própria no Render e compartilhando o Neon e o HiveMQ. A API permanece 100% na Vercel. *(Decidido em 16/10 — card US-37.)*

> **Adendo (18/10/2026) — transporte do terminal:** a decisão de usar HTTP(S) direto do ESP32 para QR/NFC/heartbeat foi revista antes da implementação. O terminal fala **MQTT bidirecional** com o backend (QR, eventos, heartbeat, ACK) e o app fala HTTPS com a API. A API continua serverless na Vercel e publica comandos MQTT pontuais; o processo MQTT que assina os tópicos roda localmente na S1 (US-04) e no Render a partir da S2 (US-37). O worker **não compartilha o domínio da API** (URL própria no Render). A matriz detalhada fica em `docs/architecture/visao-geral.md`; o contrato, em `docs/architecture/contratos-mqtt.md` (US-04).

> **Adendo (19/10/2026) — entrada e CD da API:** a Vercel passou a rodar Express sem configuração, então o adaptador `api/index.ts` previsto acima não é necessário: o app é exportado por `backend/src/index.ts` e o deploy sai pelo `cd-backend.yml` (Vercel CLI no GitHub Actions, com o Root Directory `backend` no projeto). O `/health` público também verifica a conexão com o Neon (`database`). Passo a passo em [`../../guides/deploy.md`](../../guides/deploy.md).

- O Docker segue obrigatório no desenvolvimento (compose) e continua disponível como caminho alternativo de deploy, atendendo RP12.

## Limites dos planos gratuitos (verificados em 16/10/2026)

| Serviço | Limite relevante | Impacto / mitigação |
|---|---|---|
| **Vercel (Hobby)** | Funções executam por até **10 s** por request · uso não-comercial (projeto acadêmico ✓) | Manter handlers enxutos; o publish MQTT pontual cabe folgado (<1 s). |
| **Render (free)** | Web service **dorme após 15 min sem tráfego HTTP** — conexões MQTT de saída **não contam** como tráfego | O worker faz **self-ping HTTP a cada 10 min** (keep-alive) — requisito do US-37. Alternativa robusta: VM "Always Free" da Oracle. |
| **Neon (free)** | 1 GB de storage por projeto · 100 CU-hours/mês · autosuspend de 5 min | Suficiente para o projeto; primeira query após ocioso leva ~1 s. Usar o endpoint **`-pooler`**. |
| **HiveMQ Cloud (Serverless/free)** | 100 conexões · 10 GB/mês · retenção de 3 dias · **clusters Serverless têm EOL em 31/12/2026** | Cobre todo o semestre (entrega final em dez/2026). Plano B documentado: **EMQX Cloud Serverless** (free) ou Mosquitto numa VM. |
| **GitHub Actions** | Repositório **público** → minutos ilimitados | CI/CD do time sem custo. |
| **Figma (Education)** | 200 chamadas de MCP por dia | Design sem gargalo no semestre. |
