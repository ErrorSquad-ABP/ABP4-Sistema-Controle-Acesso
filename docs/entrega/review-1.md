# Review 1 — Documento de entrega · Sprint 1

- **Curso**: Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí
- **Projeto**: ABP 2026-2 · Sistema Integrado de Controle de Acesso (QR Code + NFC + IoT)
- **Equipe**: ErrorSquad — SM: João Victor Lopes Rosa · PO: Felipe Pacheco · Devs: Carlos Santo, Caio Araujo, Leo Silva, Arthur Facchinetti
- **Sprint**: 1 (15/10 → 21/10/2026) · **Review**: 21/10/2026, 19h30
- **Goal**: "Fundação no ar + esqueleto conversando ponta-a-ponta, simulado"

## 1. Resultado

**10 de 13 cards concluídos (77%)**, com a fundação e os três esqueletos no ar. Nenhuma história incompleta foi marcada como concluída: US-07, US-08 e US-10 foram movidas para a Sprint 2 com os mesmos donos.

| Indicador | Resultado |
|---|---|
| Cards concluídos | 10/13 |
| PRs mergeados na `main` | 10 (#2 a #11) |
| Testes de backend | 122 passando |
| Testes de mobile | 12 passando |
| Checks obrigatórios | 4 (backend, backend-docker, mobile, firmware) + CodeQL |
| Deploy | API no ar com banco em nuvem (`database: ok`) |

## 2. O que está no ar

| Superfície | Link |
|---|---|
| API (produção) | https://abp-4-sistema-controle-acesso.vercel.app/health |
| Repositório | https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso |
| Board (fonte viva) | https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm |
| Design (Figma) | https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl |

## 3. Entregas por card

| US | Entrega | Evidência |
|---|---|---|
| US-01 | Monorepo, README, guias, templates, `CODEOWNERS`, branch protegida, compose Mosquitto + Postgres | `main`, `infra/docker-compose.dev.yml` |
| US-02 | CI trio (backend, mobile, firmware) + CodeQL + workflow que anexa PR ao card do Trello | `.github/workflows/` |
| US-03 | Backend Express/TS em 4 camadas, `env.ts`, `/health`, error handler, Dockerfile, caso de uso modelo | `backend/src/`, `docs/architecture/caso-de-uso-modelo.md` |
| US-04 | Contrato MQTT v1 (tópicos, payloads, QoS, expiração), consumidor local e simulador de terminal | `docs/architecture/contratos-mqtt.md`, `backend/src/infrastructure/mqtt/` |
| US-05 | `schema.prisma` (User, AccessLocation, Authorization, AccessEvent, Credential), migration, seed e diagrama ER | `backend/prisma/`, `docs/architecture/modelo-dados.md` |
| US-06 | OpenAPI 3.1 v1 e rotas stub validadas com Zod (501) | `docs/api/openapi.yaml`, `backend/src/infrastructure/http/` |
| US-09 | App Flutter com Riverpod, go_router, tema claro/escuro alinhado ao design system | `mobile/lib/core/` |
| US-11 | Processo Scrum, product backlog (38 stories), DoD, sprints 1–3 e templates | `docs/scrum/` |
| US-12 | Design system (Figtree), fluxo do usuário e estados; 23 assets exportados | `design/figma/`, `design/README.md` |
| US-13 | CD do backend na Vercel com Neon; `/health` público conectado ao banco | `.github/workflows/cd-backend.yml`, `/health` |

## 4. Estado técnico

- **Backend**: Node + Express + TypeScript, Clean Architecture pragmática, Prisma/PostgreSQL (Neon), Zod, mqtt.js, Vitest. Deploy serverless na Vercel.
- **Mobile**: Flutter + Riverpod + go_router; login mock com contrato para a API (US-06) e tema derivado do design system. Scanner e geolocalização ficam para a S2.
- **Firmware**: ESP32 + PlatformIO, módulos de mqtt/display/nfc/gps/feedback/door, `config.example.h` sem segredos, testes host no CI e simulação Wokwi configurada.
- **Infra dev**: Docker Compose com Eclipse Mosquitto e PostgreSQL, espelhando o ambiente legado.
- **Qualidade**: PR obrigatório com 1 review, checks obrigatórios na `main`, CodeQL em todo PR, convenções de commit e rastreio `US-XX`.

## 5. O que não entrou na Sprint 1

| US | Situação | Destino |
|---|---|---|
| US-07 · Esqueleto firmware | Código e CI verdes (PR #12); falta executar a conexão Wokwi→Mosquitto, que é critério de aceite | S2 com Art — validação como primeiro passo |
| US-10 · Login & scanner | Apenas o login mock (PR #13); scanner, geolocalização, sessão e pt-BR não foram entregues | S2 com Art — login vira base da US-27; scanner na US-29 |
| US-08 · Herança do protótipo | Não iniciada (sem branch/PR) | S2 com Caio, após a validação da US-07 |

**Causa comum**: os cards de firmware/mobile chegaram no último dia da sprint, sem margem para review e correção. O corte foi aplicado conforme a política registrada em `docs/scrum/sprints/sprint-1.md`.

## 6. Riscos e mitigação

| Risco | Mitigação |
|---|---|
| Validação de hardware/Wokwi não roda no CI | Roteiro documentado em `firmware/README.md` + demo registrada no card; primeira tarefa da S2 |
| Escopo maior que a sprint (S2 tem 13 stories) | Estimativa na Planning 2 e fatiamento explícito; US-21 entra fatiada |
| Android SDK ausente em ambiente de dev | Instalação documentada na S2; build web já validado |
| Broker/credenciais em produção | HiveMQ Cloud com TLS e tópicos namespaceados; segredos só em GitHub Secrets |

## 7. Próxima sprint (S2 · 22/10 → 11/11)

Foco: **fluxo QR real ponta-a-ponta + admin + deploy + design admin/terminal** (13 stories previstas em `docs/scrum/sprints/sprint-2.md`). A Planning 2 fecha o goal, a estimativa e os cortes; a primeira ação técnica é concluir a validação Wokwi e fechar a US-07.

## 8. Rastreabilidade

- Processo e fechamento: `docs/scrum/sprints/sprint-1.md` · `sprint-1-review.md` · `sprint-1-retro.md`
- Backlog e aceite: `docs/scrum/product-backlog.md`
- Cada card do Trello tem o checklist de aceite, o PR anexado e o status atualizado.
