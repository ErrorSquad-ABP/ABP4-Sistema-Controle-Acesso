# Product Backlog — ErrorSquad ABP 4DSM

Este é o backlog oficial do **Sistema Integrado de Controle de Acesso** (QR Code + NFC + IoT): as 36 user stories do projeto, organizadas por épico. As 13 stories da **Sprint 1** estão detalhadas abaixo (narrativa + critérios de aceite); as outras 23 estão previstas por sprint e são refinadas/estimadas sprint a sprint, a partir da Sprint 2.

Duas superfícies, dois papéis: o **Trello** (board `ERRORSQUAD ABP 4DSM`) é a fonte viva — onde o card se move durante a sprint; **este documento** é a fonte oficial — o backlog como o time acordou, espelhado nos cards do board.

## Épicos

| Épico | Nome | Escopo |
|---|---|---|
| E1 | Fundação & Infraestrutura | Repo, CI/CD, containers, deploy, broker, banco |
| E2 | Backend | Identidade/perfis, autorizações (criar/consultar/cancelar), validação QR/NFC + geofence, eventos e histórico |
| E3 | Terminal IoT | Display do QR rotativo, leitura NFC, GPS, feedback (LED/buzzer), servo, comunicação MQTT resiliente |
| E4 | App Mobile | Login, minhas autorizações, scanner QR, resultados, admin (usuários, autorizações, histórico) |
| E5 | Integração & Confiabilidade | Contrato MQTT, fluxos ponta-a-ponta, retry/persistência local, testes E2E, segurança |
| E6 | Documentação & Entrega | Arquitetura, diagramas, guias, relatório, apresentação, acessibilidade (RNF04 — público idoso) |

## Notas de processo

- **Estimativa**: acontece na **Planning 1**. Até lá, os pontos de todo card ficam `— (Planning 1)` e nenhum valor é chutado aqui.
- **Prioridade**: definida pelo **PO** (designado pelo time na Planning 1), não pela ordem em que as stories aparecem.
- **Dono**: nenhuma story nasce com assignee. Na Sprint 1 a divisão é 3 cards de alicerce com o SM e 2 cards para cada um dos 5 devs; cada um puxa o seu card na Planning 1.
- **Formato do card no Trello**: título `US-XX · Título`; descrição com a narrativa ("Como… quero… para…"), critérios de aceite em **checklist**, pontos e épico `(E1…E6)` no sufixo do título. Modelo completo na US-04.
- **Rastreio**: `US-XX` no card → título da branch → título/corpo do PR → execução.
- **Sprint 4** = janela de entrega final (26/11 → data oficial da apresentação); a Sprint 3 termina na Review 3.
- **Cortes de segurança** da Sprint 1 (se a sprint apertar): US-08 e US-10 podem escorregar para a Sprint 2 sem quebrar a review.

---

## Sprint 1 — 13 stories detalhadas

**Goal**: fundação no ar + esqueleto conversando ponta-a-ponta, simulado (15/10 → 21/10, Review em 21/10).

### US-01 · Repo vivo

- **Épico**: E1 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como time de desenvolvimento, quero um repositório com a estrutura de monorepo, os guias internos e os templates já prontos, para começar a Sprint 1 escrevendo código e abrindo PRs no padrão do time em vez de montar o esqueleto.

**Critérios de aceite**:

- [ ] Estrutura do monorepo criada (`backend/`, `mobile/`, `firmware/`, `docs/`, `infra/`, `design/`, `.github/`)
- [ ] `README.md` raiz com a visão geral do projeto
- [ ] Guias internos (`docs/guides/desenvolvimento.md` e `como-rodar.md`)
- [ ] Templates de PR e de issue
- [ ] `CODEOWNERS` configurado
- [ ] Branch `main` protegida
- [ ] `docker-compose.dev.yml` sobe Mosquitto + Postgres

### US-02 · CI trio + vínculo Trello↔PR

- **Épico**: E1 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev, quero que todo PR rode lint, typecheck, testes e build das três stacks e que o card `US-XX` seja anexado e comentado automaticamente, para integrar trabalho com segurança e sem atualizar status na mão.

**Critérios de aceite**:

- [ ] Workflow `ci-backend.yml` verde em PR (lint + typecheck + test + build)
- [ ] Workflow `ci-mobile.yml` verde em PR (analyze + test)
- [ ] Workflow `ci-firmware.yml` verde em PR (build)
- [ ] Workflow `trello-link.yml` anexa o PR ao card `US-XX` e comenta o status
- [ ] Secrets configurados sem exposição de valores

### US-03 · Esqueleto backend

- **Épico**: E2 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev backend, quero um esqueleto Express + TypeScript com as 4 camadas da Clean Architecture, healthcheck e tratamento de erro padronizado, para implementar os casos de uso seguindo um caso de uso modelo já documentado.

**Critérios de aceite**:

- [ ] Clean Architecture nas 4 pastas (`domain/`, `application/`, `infrastructure/`, `main/`)
- [ ] `env.ts` validando as variáveis de ambiente
- [ ] Endpoint de healthcheck respondendo
- [ ] Error handler padrão
- [ ] `Dockerfile` do backend
- [ ] Teste mínimo com Vitest passando
- [ ] "Caso de uso modelo" documentado como guia de extensão

### US-04 · MQTT v1 + simulador

- **Épico**: E5 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev do terminal IoT, quero o contrato MQTT dos tópicos do projeto documentado e um simulador de terminal publicando eventos, para desenvolver e testar o fluxo de acesso ponta-a-ponta sem depender do hardware físico.

**Critérios de aceite**:

- [ ] `docs/architecture/contratos-mqtt.md` com os tópicos de QR, evento de acesso, comando de abertura e heartbeat/LWT (com QoS e payloads)
- [ ] Cliente mqtt.js conectando no broker dev
- [ ] `npm run sim:terminal` publica um evento visível nos logs
- [ ] Teste unitário do parser de payloads

**Card-exemplo de formato (Trello)** — modelo para todas as stories:

```text
Título:  US-04 · MQTT v1 + simulador (E5)

Descrição:
  Como dev do terminal IoT, quero o contrato MQTT dos tópicos do projeto
  documentado e um simulador de terminal publicando eventos, para
  desenvolver e testar o fluxo de acesso ponta-a-ponta sem depender do
  hardware físico.

Checklist (Critérios de aceite):
  [ ] docs/architecture/contratos-mqtt.md (tópicos QR, evento de acesso,
      comando de abertura, heartbeat/LWT; QoS/payloads)
  [ ] Cliente mqtt.js conectando no broker dev
  [ ] npm run sim:terminal publica evento visível nos logs
  [ ] Teste unitário do parser

Pontos:   — (Planning 1)
Épico:    E5 — Integração & Confiabilidade
```

### US-05 · Modelo de dados v1

- **Épico**: E2 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev backend, quero o schema Prisma com as entidades do domínio e um seed de demonstração, para que os casos de uso e o app tenham dados reais para trabalhar desde a primeira sprint.

**Critérios de aceite**:

- [ ] `schema.prisma` com `User`, `AccessLocation`, `Authorization`, `AccessEvent` e `Credential`
- [ ] Migration aplicada
- [ ] Seed de demonstração

### US-06 · OpenAPI v1

- **Épico**: E2 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev mobile, quero o contrato OpenAPI das rotas de auth, users, authorizations e access-events, para integrar o app contra um contrato congelado sem esperar a implementação do backend.

**Critérios de aceite**:

- [ ] `docs/api/openapi.yaml` cobrindo auth, users, authorizations e access-events
- [ ] Rotas stub validadas com Zod (respondendo 501)
- [ ] Contrato congelado para o mobile

### US-07 · Esqueleto firmware

- **Épico**: E3 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev de firmware, quero o projeto PlatformIO com os módulos separados por responsabilidade e a simulação no Wokwi conectada ao Mosquitto do compose, para evoluir o terminal sem depender de hardware em mãos.

**Critérios de aceite**:

- [ ] Projeto PlatformIO com os módulos do terminal
- [ ] `config.example.h` (WiFi/broker/tópicos) sem segredos
- [ ] Simulação Wokwi conectando no Mosquitto do `docker-compose.dev.yml`

### US-08 · Herança do protótipo

- **Épico**: E3 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev de firmware, quero portar servo, LED, buzzer e LCD do protótipo legado para módulos do projeto novo, para reaproveitar o que já funciona e demonstrar o ciclo de abertura com feedback no Wokwi.

**Critérios de aceite**:

- [ ] Servo, LED, buzzer e LCD portados do sketch legado para módulos
- [ ] Ciclo abrir/fechar + feedback demonstrado no Wokwi

### US-09 · Esqueleto Flutter

- **Épico**: E4 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev mobile, quero o app Flutter com Riverpod, go_router e o tema base casado com o design system, para construir as telas seguindo o layout já definido no Figma.

**Critérios de aceite**:

- [ ] Riverpod + go_router configurados
- [ ] Tema base casado com o Figma (US-12)
- [ ] `flutter analyze` limpo
- [ ] Teste widget mínimo

### US-10 · Login & scanner (esqueleto)

- **Épico**: E4 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como usuário do sistema, quero uma tela de login e um leitor de QR Code no app, para conseguir entrar e ler o código do terminal já na primeira sprint, mesmo com os dados ainda mockados.

**Critérios de aceite**:

- [ ] Tela de login (mock → API da US-06 quando disponível)
- [ ] Scanner de QR com `mobile_scanner`
- [ ] Permissão de geolocalização (`geolocator`)

### US-11 · Documentos Scrum

- **Épico**: E6 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como time, quero os documentos Scrum dentro do repo (processo, product backlog, DoD, sprints e templates), para ter um processo rastreável e consistente com a spec desde a fundação do projeto.

**Critérios de aceite**:

- [ ] `docs/scrum/` completo: processo, product backlog com as ~35 stories, DoD, sprints 1–3 e templates de review/retro
- [ ] Conteúdo consistente com a spec aprovada

### US-12 · Design no Figma (fase 1)

- **Épico**: E6 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev, quero o design system e o fluxo do usuário desenhados no Figma, para implementar as telas mobile com tipografia, cores e componentes já definidos, sem decidir visual na hora do código.

**Critérios de aceite**:

- [ ] Design system (styles, tipografia Inter, componentes base)
- [ ] Fluxo do usuário: login, autorizações, scanner, resultado e estados

### US-13 · CD + deploy inicial

- **Épico**: E1 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como time, quero o deploy automático do backend após merge na `main`, para validar a entrega em ambiente real (Render + Neon) já na Sprint 1, com healthcheck público.

**Critérios de aceite**:

- [ ] Workflow `cd-backend.yml` disparando deploy após merge na `main`
- [ ] Backend do esqueleto no ar no Render com healthcheck público
- [ ] Neon provisionado
- [ ] Secrets configurados

---

## Backlog futuro — US-14 a US-36 (23 stories)

Descobertas por sprint. Títulos, épico e sprint alvo conforme previsto; o refinamento fatiar e detalha cada uma antes da sprint em que entra (narrativa + critérios de aceite + pontos).

| US | Título | Épico | Sprint alvo |
|---|---|---|---|
| US-14 | Auth JWT + perfis | E2 | S2 |
| US-15 | CRUD de usuários admin | E2 | S2 |
| US-16 | Criar autorização admin | E2 | S2 |
| US-17 | Consultar/cancelar autorização admin | E2 | S2 |
| US-18 | Minhas autorizações usuário | E2 | S2 |
| US-19 | Credencial QR rotativa + validação 10s | E2 | S2 |
| US-20 | Validação de acesso QR com geofence 100m | E2 | S2 |
| US-21 | Eventos de acesso + histórico com filtros | E2 | S2/S3 |
| US-22 | Display: render do QR + status | E3 | S2 |
| US-23 | NFC RC522 + feedback de decisão | E3 | S3 |
| US-24 | GPS + heartbeat | E3 | S3 |
| US-25 | Resiliência: retry/reconexão/persistência local | E3 | S3 |
| US-26 | Comando de abertura do servo via MQTT | E3 | S2 |
| US-27 | Login real + sessão | E4 | S2 |
| US-28 | Minhas autorizações no app | E4 | S2 |
| US-29 | Scanner QR + resultado no app | E4 | S2 |
| US-30 | Admin: autorizações criar/consultar/cancelar | E4 | S3 |
| US-31 | Admin: usuários e histórico + acessibilidade idoso | E4 | S3 |
| US-32 | E2E simulado no CI | E5 | S3 |
| US-33 | Revisão de segurança | E5 | S3 |
| US-34 | Teste em hardware real | E5 | S3 |
| US-35 | Diagramas e docs de arquitetura finais | E6 | S3 |
| US-36 | Relatório ABNT e apresentação final | E6 | S4 |

**Distribuição por épico**: E1 com 3 cards (todos na Sprint 1, a fundação não tem story futura) · E2 com 11 · E3 com 7 · E4 com 7 · E5 com 4 · E6 com 4 — **36 stories no total**, sendo 13 detalhadas na Sprint 1 e 23 futuras.

## Índice

- [`README.md`](README.md) — como o time aplica o Scrum.
- [`definition-of-done.md`](definition-of-done.md) — o que significa "pronto" para um card.
- `sprints/` e `templates/` completam a pasta (US-11).
