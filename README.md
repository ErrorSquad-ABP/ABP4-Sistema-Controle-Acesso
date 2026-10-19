# ABP4 · Sistema de Controle de Acesso

[![ci-backend](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml)
[![ci-mobile](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml)
[![ci-firmware](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml)

Sistema integrado de baixo custo para o controle de acesso em edifícios: um Terminal de Acesso exibe um QR Code rotativo (gerado no backend e renovado a cada 10 segundos) e também lê tags NFC; o app móvel autentica o usuário, escaneia o QR e informa a geolocalização; o backend em nuvem concentra as regras de acesso — credenciais, autorizações, janelas de uso, limite de 100 m e registro de eventos — e conversa com o terminal por MQTT. Este monorepo reúne backend, mobile, firmware, infraestrutura e documentação do projeto.

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

Na S1 o processo MQTT roda localmente (US-04); na S2 ele vai para o Render (US-37). A Vercel hospeda só a API. Detalhes dos fluxos de acesso (QR e NFC), dos ambientes e do contrato MQTT em [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md).

## Estrutura do monorepo

Itens marcados com `*` são previstos (ainda não existem) e entram pelos cards indicados.

```text
ABP4-Sistema-Controle-Acesso/
├─ backend/                  Node + Express + TypeScript
│  ├─ src/                   domain · application · infrastructure · main · shared
│  ├─ prisma/                * US-05: schema.prisma · migrations · seed.ts
│  └─ tests/                 unit/ · integration/
├─ mobile/                   Flutter
│  ├─ lib/                   core/ · features/ (auth, authorizations, scanner, admin — previstas)
│  └─ test/ · pubspec.yaml
├─ firmware/                 * US-07/08: ESP32 · PlatformIO (C++)
│  ├─ src/                   * main.cpp + módulos (mqtt, display, nfc, gps, feedback, door)
│  ├─ include/               * config.example.h (WiFi/broker/tópicos — sem segredos)
│  ├─ wokwi/                 * diagram.json + simulação
│  └─ platformio.ini         *
├─ docs/
│  ├─ scrum/                 processo, product-backlog, DoD, sprints e templates
│  ├─ architecture/          visao-geral.md · * contratos-mqtt.md (US-04) · * modelo-dados.md (US-05) · adr/
│  ├─ api/                   * openapi.yaml (US-06)
│  └─ guides/                desenvolvimento.md · como-rodar.md
├─ infra/                    docker-compose.dev.yml (Mosquitto + Postgres) · mosquitto/
├─ design/                   export de assets do Figma
├─ .github/
│  ├─ workflows/             ci-backend.yml · ci-mobile.yml · ci-firmware.yml ·
│  │                         * cd-backend.yml (US-13) · trello-link.yml
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
| Infra prod | **Vercel** (API serverless) · **Render** (worker MQTT) · **Neon** (Postgres) · HiveMQ Cloud (MQTT TLS) | Free tiers; atende RNF06, RP11, RNF02 · ver `docs/architecture/adr/001` |

## Como rodar localmente

Passo a passo de ambiente, infraestrutura e execução em [`docs/guides/como-rodar.md`](docs/guides/como-rodar.md).

## Documentação

- [`docs/scrum/README.md`](docs/scrum/README.md) — como o time aplica Scrum (backlog, DoD, sprints e templates).
- [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md) — arquitetura, fluxos de acesso e contrato MQTT.
- [`docs/guides/desenvolvimento.md`](docs/guides/desenvolvimento.md) — branches, commits, PRs, review e CI.
- [`docs/architecture/caso-de-uso-modelo.md`](docs/architecture/caso-de-uso-modelo.md) — como estender o backend (camadas, erros, env, testes).

## Equipe

**ErrorSquad** · ABP 2026-2 · 4DSM · FATEC Jacareí — SM: João Victor Lopes Rosa ([@JV-L0pes](https://github.com/JV-L0pes)) · PO: Felipe Pacheco ([@FelipePacheco30](https://github.com/FelipePacheco30)) · Devs: [@Carlos-Santo](https://github.com/Carlos-Santo), [@Caiuuutecnologico](https://github.com/Caiuuutecnologico), [@Leo-Slv](https://github.com/Leo-Slv), [@ArtFacchinetti](https://github.com/ArtFacchinetti).
