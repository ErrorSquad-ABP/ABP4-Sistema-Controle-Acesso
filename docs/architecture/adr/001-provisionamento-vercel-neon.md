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
  - Se no futuro o time quiser um worker MQTT persistente, ele roda **fora da Vercel** (ex.: Render free) sem alterar a API — decisão adiada (YAGNI).
- O Docker segue obrigatório no desenvolvimento (compose) e continua disponível como caminho alternativo de deploy, atendendo RP12.
