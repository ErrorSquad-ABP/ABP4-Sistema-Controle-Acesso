# ABP4 · Sistema de Controle de Acesso

[![ci-backend](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml)
[![ci-mobile](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml)
[![ci-firmware](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml)

Sistema integrado de baixo custo para controle de acesso em edifícios, com arquitetura prevista de terminal ESP32 (QR rotativo + NFC), app Flutter e backend Node/TypeScript por REST e MQTT. Este monorepo reúne backend, mobile, firmware, infraestrutura e documentação do projeto.

## Estado atual — 02/11/2026 · board reconferido em 08/11/2026 · atualizado em 10/11/2026

- **Backend:** login JWT/RBAC, usuários, autorizações, QR assinado de 25 s, decisão de acesso, histórico, outbox e processamento MQTT implementados. Autorizações usam intervalo contínuo; a DT-23 limita o QR ao menor valor entre o raio do local e 100 m, com restrição de cadastro no banco, implantada em produção em 10/11.
- **App:** login real/sessão e leitura QR + posição implementados; o scanner **ainda não envia o pedido de acesso** (US-29). Minhas autorizações e admin ainda não têm telas funcionais completas.
- **Terminal:** código de display QR, servo e feedback presente; NFC/GPS são esqueletos e status/heartbeat segue pendente. O TLS do broker foi validado no ESP32 contra o EMQX (DT-06); servo/PWM e ACK ainda não.
- **Operação:** API pública respondeu em 10/11 com `version: 2dd532b`, `database: ok`; worker no Render continua sem deploy comprovado.
- **Trello:** o board foi reconferido em 08/11 e atualizado pelos merges de 09–10/11; a contagem viva deve ser lida no Trello. Permanecem ressalvas de aceite e escopo, especialmente US-37 (deploy) e US-10/22 (demonstração real). DT-06, DT-08, DT-23 e DT-24 foram concluídas.

Conferência dos **44 cards**, evidências, testes e pendências em [`docs/entrega/auditoria-estado-atual.md`](docs/entrega/auditoria-estado-atual.md). Código integrado, simulação e operação real são tratados separadamente; o fluxo completo app → terminal real ainda não foi demonstrado.

## Arquitetura

```mermaid
flowchart LR
  A[App Flutter] -- HTTPS REST --> B[API Express/TS · Vercel]
  A -- camera QR + GPS --> A
  T[Terminal ESP32] -- MQTT --> M[(Broker MQTT)]
  M -- MQTT --> W[Processo MQTT · local S1 / Render S2]
  B -- comando MQTT --> M
  B -- regras --> DB[(PostgreSQL)]
  W -- regras --> DB
```

Na S1 o processo MQTT roda localmente (US-04); na S2 foi preparado para o Render (US-37, PR #26) — o código e o `render.yaml` estão na `main`, mas o deploy efetivo **não foi observado**. A Vercel hospeda só a API. O polling de recuperação da outbox roda apenas entre **18:45 e 23:05** em `America/Sao_Paulo` (DT-21, PR #45); isso não bloqueia publicação imediata, consultas normais ou expurgos. Detalhes dos fluxos de acesso (QR e NFC), dos ambientes e da matriz de transporte em [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md); tópicos, payloads, QoS e expiração do MQTT em [`docs/architecture/contratos-mqtt.md`](docs/architecture/contratos-mqtt.md).

## Estrutura do monorepo

As pastas abaixo existem; funcionalidades previstas dentro delas são identificadas explicitamente.

```text
ABP4-Sistema-Controle-Acesso/
├─ backend/                  Node + Express + TypeScript
│  ├─ src/                   domain · application · infrastructure · main · shared
│  ├─ prisma/                schema.prisma · migrations · seed.ts
│  └─ tests/                 unit/ · integration/
├─ mobile/                   Flutter
│  ├─ lib/                   core/ · features/ (auth, home, scanner; authorizations/admin pendentes)
│  └─ test/ · pubspec.yaml
├─ firmware/                 ESP32 · PlatformIO (C++); validação física na US-34
│  ├─ src/                   main.cpp + modules/ (mqtt, display, nfc, gps, feedback, door)
│  ├─ include/               config.example.h (WiFi/broker/tópicos — sem segredos)
│  ├─ wokwi/                 diagram.json + wokwi.toml
│  └─ platformio.ini
├─ docs/
│  ├─ scrum/                 processo, product-backlog, DoD, sprints e templates
│  ├─ architecture/          visao-geral.md · contratos-mqtt.md · modelo-dados.md · adr/
│  ├─ api/                   openapi.yaml (gerado) · README.md — contrato REST v1
│  └─ guides/                desenvolvimento.md · como-rodar.md · deploy.md
├─ infra/                    docker-compose.dev.yml (Mosquitto + Postgres) · mosquitto/
├─ design/                   export de assets do Figma
├─ .github/
│  ├─ workflows/             ci-backend.yml · ci-mobile.yml · ci-firmware.yml ·
│  │                         cd-backend.yml · trello-link.yml
│  └─ CODEOWNERS · PULL_REQUEST_TEMPLATE.md · ISSUE_TEMPLATE/
└─ README.md · .gitignore · .editorconfig
```

**Regra de dependência (backend)**: `domain` não importa nada externo; `application` importa só `domain`; `infrastructure` implementa os contratos; `main` monta tudo. Casos de uso não conhecem Express, Prisma ou MQTT — falam via interfaces.

## Stacks

| Área | Stack | Observações |
|---|---|---|
| Backend | Node LTS + Express + TypeScript, Prisma + PostgreSQL, Zod, mqtt.js, JWT, Vitest | Versões pinadas na implementação conforme docs atuais |
| Mobile | Flutter, Riverpod, go_router, `mobile_scanner` (QR), `geolocator` | Android é o alvo principal da entrega |
| Firmware | ESP32, PlatformIO (C++/Arduino), módulos por responsabilidade, Wokwi p/ simulação | Reaproveita lógica do sketch legado (servo/LED/buzzer) |
| Infra dev | docker-compose: Eclipse Mosquitto + PostgreSQL | Espelha o legado; atende RP12 |
| Infra prod | **Vercel** (API serverless) · **Render** (worker MQTT) · **Neon** (Postgres) · EMQX Cloud (MQTT TLS) | Free tiers; atende RNF06, RP11, RNF02 · ver `docs/architecture/adr/001` |

## Como rodar localmente

Passo a passo de ambiente, infraestrutura e execução em [`docs/guides/como-rodar.md`](docs/guides/como-rodar.md).

## Documentação

- [`docs/entrega/auditoria-estado-atual.md`](docs/entrega/auditoria-estado-atual.md) — estado em 02/11/2026 e auditoria dos concluídos no Trello.
- [`docs/scrum/README.md`](docs/scrum/README.md) — como o time aplica Scrum (backlog, DoD, sprints e templates).
- [`docs/entrega/review-1.md`](docs/entrega/review-1.md) — documento de entrega da Review 1 (Sprint 1).
- [`docs/entrega/README.md`](docs/entrega/README.md) — índice das evidências por card (`docs/entrega/evidencias/`).
- [`docs/entrega/matriz-requisitos.md`](docs/entrega/matriz-requisitos.md) — matriz do edital (RF, RNF e RP) com status e lacunas.
- [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md) — arquitetura, fluxos de acesso e matriz de transporte.
- [`docs/architecture/contratos-mqtt.md`](docs/architecture/contratos-mqtt.md) — contrato MQTT v1 (tópicos, payloads, QoS, ids e expiração).
- [`docs/architecture/modelo-dados.md`](docs/architecture/modelo-dados.md) — diagrama ER do modelo Prisma v1.
- [`docs/guides/desenvolvimento.md`](docs/guides/desenvolvimento.md) — branches, commits, PRs, review e CI.
- [`docs/architecture/caso-de-uso-modelo.md`](docs/architecture/caso-de-uso-modelo.md) — como estender o backend (camadas, erros, env, testes).

## Equipe

**ErrorSquad** · ABP 2026-2 · 4DSM · FATEC Jacareí — SM: João Victor Lopes Rosa ([@JV-L0pes](https://github.com/JV-L0pes)) · PO: Felipe Pacheco ([@FelipePacheco30](https://github.com/FelipePacheco30)) · Devs: [@Carlos-Santo](https://github.com/Carlos-Santo), [@Caiuuutecnologico](https://github.com/Caiuuutecnologico), [@Leo-Slv](https://github.com/Leo-Slv), [@ArtFacchinetti](https://github.com/ArtFacchinetti).
