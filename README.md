# ABP4 · Sistema de Controle de Acesso

Sistema integrado de baixo custo para o controle de acesso em edifícios: um Terminal de Acesso exibe um QR Code rotativo (gerado no backend e renovado a cada 10 segundos) e também lê tags NFC; o app móvel autentica o usuário, escaneia o QR e informa a geolocalização; o backend em nuvem concentra as regras de acesso — credenciais, autorizações, janelas de uso, limite de 100 m e registro de eventos — e conversa com o terminal por MQTT. Este monorepo reúne backend, mobile, firmware, infraestrutura e documentação do projeto.

## Arquitetura

```mermaid
flowchart LR
  A[App Flutter] -- HTTPS REST --> B[Backend Express/TS]
  A -- camera QR + GPS --> A
  T[Terminal ESP32] -- MQTT --> M[(Broker MQTT)]
  M -- MQTT --> B
  B -- QR rotativo / comando --> M
  B -- regras de acesso --> DB[(PostgreSQL)]
```

Detalhes dos fluxos de acesso (QR e NFC), dos ambientes e do contrato MQTT em [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md).

## Estrutura do monorepo

```text
ABP4-Sistema-Controle-Acesso/
├─ backend/                  Node + Express + TypeScript
│  ├─ src/                   domain · application · infrastructure · main · shared
│  ├─ prisma/                schema.prisma · migrations · seed.ts
│  └─ tests/                 unit/ · integration/
├─ mobile/                   Flutter
│  ├─ lib/                   core/ · features/ (auth, authorizations, scanner, admin)
│  └─ test/ · pubspec.yaml
├─ firmware/                 ESP32 · PlatformIO (C++)
│  ├─ src/                   main.cpp + módulos (mqtt, display, nfc, gps, feedback, door)
│  ├─ include/               config.example.h (WiFi/broker/tópicos — sem segredos)
│  ├─ wokwi/                 diagram.json + simulação
│  └─ platformio.ini
├─ docs/
│  ├─ scrum/                 processo, product-backlog, DoD, sprints e templates
│  ├─ architecture/          visao-geral.md · contratos-mqtt.md · modelo-dados.md · adr/
│  ├─ api/                   openapi.yaml
│  └─ guides/                desenvolvimento.md · como-rodar.md
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
| Infra prod | **Vercel** (API serverless) · **Neon** (Postgres) · HiveMQ Cloud (MQTT TLS) | Free tiers; atende RNF06, RP11, RNF02 · ver `docs/architecture/adr/001` |

## Como rodar localmente

Passo a passo de ambiente, infraestrutura e execução em [`docs/guides/como-rodar.md`](docs/guides/como-rodar.md).

## Documentação

- [`docs/scrum/README.md`](docs/scrum/README.md) — como o time aplica Scrum (backlog, DoD, sprints e templates).
- [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md) — arquitetura, fluxos de acesso e contrato MQTT.
- [`docs/guides/desenvolvimento.md`](docs/guides/desenvolvimento.md) — branches, commits, PRs e review.

## Equipe

**ErrorSquad** · ABP 2026-2 · 4DSM · FATEC Jacareí — Scrum Master: João Victor Lopes Rosa. Os demais integrantes entram nesta lista quando forem adicionados ao projeto.
