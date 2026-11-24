# ABP4 · Sistema de Controle de Acesso

[![ci-backend](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-backend.yml)
[![ci-mobile](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-mobile.yml)
[![ci-firmware](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml/badge.svg?branch=main)](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/workflows/ci-firmware.yml)

Sistema integrado de baixo custo para controle de acesso em edifícios, com arquitetura prevista de terminal ESP32 (QR rotativo + NFC), app Flutter e backend Node/TypeScript por REST e MQTT. Este monorepo reúne backend, mobile, firmware, infraestrutura e documentação do projeto.

## Estado atual — 24/11/2026 (entrega final)

- **Backend:** login JWT/RBAC, usuários, autorizações, locais, QR assinado de 25 s, prova HCE, decisão de acesso, histórico, outbox e processamento MQTT implementados. A suíte teve **450 testes aprovados** no merge do fluxo HCE; o CI mantém lint, typecheck, testes, build e E2E. A API de produção responde com `database: ok` e libera a origem exata da demo web no CORS. A revisão de segurança está no PR #76, em revisão por pares.
- **App:** as **12 telas do Figma** (claro/escuro), o shell com abas e as telas de administração estão implementadas. O scanner lê o QR e envia o pedido; o acesso por NFC usa HCE com prova efêmera. A localização passou a ser buscada na abertura do app, não só na leitura, mantendo o limite de 10 s. São **664 testes** de Flutter e análise estática limpa; a execução em aparelho usou APK debug (Motorola g86 5G, Android 15).
- **Terminal:** o QR numérico de 41 dígitos é desenhado inteiro no OLED, com status no LCD. O RC522 lê tag física e prova HCE; o servo posicional, LEDs e buzzer respondem à decisão. O heartbeat/LWT está no firmware da `main` (US-24), pendente de confirmação no ESP32. O GPS do terminal ficou fora do escopo porque o módulo NEO-6M não estava disponível; o terminal não publica coordenada.
- **Operação:** API na Vercel, worker `abp4-mqtt-worker` no Render, PostgreSQL no Neon e broker EMQX Cloud com TLS; `/health` e `/healthz` responderam ok em 24/11. A demo web está em [abp4-demo-web.vercel.app](https://abp4-demo-web.vercel.app). O consumo elétrico não foi medido; a DT-22 foi encerrada por escopo, com orçamento e procedimento documentados.
- **Pendências declaradas:** US-25 (fila offline do firmware) está bloqueada; US-24 aguarda confirmação no hardware; US-33 aguarda revisão por pares; a abertura de uma cancela real não foi demonstrada. A matriz de requisitos aponta evidência ou lacuna para cada item.

A entrega final está em [`docs/entrega/review-3.md`](docs/entrega/review-3.md), com o relatório em [`docs/entrega/relatorio/relatorio-abnt.pdf`](docs/entrega/relatorio/relatorio-abnt.pdf), as mídias em [`docs/entrega/midias/`](docs/entrega/midias/) e o roteiro em [`docs/entrega/apresentacao/roteiro-apresentacao.md`](docs/entrega/apresentacao/roteiro-apresentacao.md).

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

Na S1 o processo MQTT roda localmente (US-04); na S2 foi preparado para o Render (US-37, PR #26) e, em 11/11, o serviço `abp4-mqtt-worker` foi observado **LIVE** com `mqtt conectado` no EMQX TLS e `/healthz` ok — a continuidade não foi medida ([`us-37.md`](docs/entrega/evidencias/us-37.md)). A Vercel hospeda só a API. O polling de recuperação da outbox roda apenas entre **18:45 e 23:05** em `America/Sao_Paulo` (DT-21, PR #45); isso não bloqueia publicação imediata, consultas normais ou expurgos. Detalhes dos fluxos de acesso (QR e NFC), dos ambientes e da matriz de transporte em [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md); tópicos, payloads, QoS e expiração do MQTT em [`docs/architecture/contratos-mqtt.md`](docs/architecture/contratos-mqtt.md).

## Estrutura do monorepo

As pastas abaixo existem; funcionalidades previstas dentro delas são identificadas explicitamente.

```text
ABP4-Sistema-Controle-Acesso/
├─ backend/                  Node + Express + TypeScript
│  ├─ src/                   domain · application · infrastructure · main · shared
│  ├─ prisma/                schema.prisma · migrations · seed.ts
│  └─ tests/                 unit/ · integration/
├─ mobile/                   Flutter
│  ├─ lib/                   core/ · app/shell/ · features/ (auth, scanner, authorizations,
│  │                         locations, profile, admin_authorizations, admin_users)
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
- [`docs/entrega/review-2.md`](docs/entrega/review-2.md) — documento de entrega da Review 2 (Sprint 2), com o estado de 11/11.
- [`docs/entrega/review-3.md`](docs/entrega/review-3.md) — documento de entrega final (Review 3), com o estado de 24/11.
- [`docs/entrega/relatorio/relatorio-abnt.pdf`](docs/entrega/relatorio/relatorio-abnt.pdf) — relatório final em ABNT (fonte em Markdown ao lado).
- [`docs/entrega/midias/README.md`](docs/entrega/midias/README.md) — diagramas, capturas da demo web e índice de mídias para slides.
- [`docs/entrega/apresentacao/roteiro-apresentacao.md`](docs/entrega/apresentacao/roteiro-apresentacao.md) — roteiro cronometrado e divisão de fala.
- [`docs/scrum/sprints/sprint-2.md`](docs/scrum/sprints/sprint-2.md) — fechamento da Sprint 2 · [review](docs/scrum/sprints/sprint-2-review.md) · [retro](docs/scrum/sprints/sprint-2-retro.md).
- [`docs/scrum/sprints/sprint-3.md`](docs/scrum/sprints/sprint-3.md) — fechamento da Sprint 3 · [review](docs/scrum/sprints/sprint-3-review.md) · [retro](docs/scrum/sprints/sprint-3-retro.md).
- [`docs/entrega/README.md`](docs/entrega/README.md) — índice das evidências por card (`docs/entrega/evidencias/`).
- [`docs/entrega/matriz-requisitos.md`](docs/entrega/matriz-requisitos.md) — matriz do edital (RF, RNF e RP) com status e lacunas.
- [`docs/architecture/visao-geral.md`](docs/architecture/visao-geral.md) — arquitetura, fluxos de acesso e matriz de transporte.
- [`docs/architecture/contratos-mqtt.md`](docs/architecture/contratos-mqtt.md) — contrato MQTT v1 (tópicos, payloads, QoS, ids e expiração).
- [`docs/architecture/modelo-dados.md`](docs/architecture/modelo-dados.md) — diagrama ER do modelo Prisma v1.
- [`docs/architecture/casos-de-uso.md`](docs/architecture/casos-de-uso.md), [`componentes-implantacao.md`](docs/architecture/componentes-implantacao.md) e [`sequencias.md`](docs/architecture/sequencias.md) — casos de uso, componentes, implantação dev/prod e sequências QR/NFC (US-35).
- [`docs/guides/desenvolvimento.md`](docs/guides/desenvolvimento.md) — branches, commits, PRs, review e CI.
- [`docs/architecture/caso-de-uso-modelo.md`](docs/architecture/caso-de-uso-modelo.md) — como estender o backend (camadas, erros, env, testes).

## Equipe

**ErrorSquad** · ABP 2026-2 · 4DSM · FATEC Jacareí — SM: João Victor Lopes Rosa ([@JV-L0pes](https://github.com/JV-L0pes)) · PO: Felipe Pacheco ([@FelipePacheco30](https://github.com/FelipePacheco30)) · Devs: [@Carlos-Santo](https://github.com/Carlos-Santo), [@Caiuuutecnologico](https://github.com/Caiuuutecnologico), [@Leo-Slv](https://github.com/Leo-Slv), [@ArtFacchinetti](https://github.com/ArtFacchinetti).
