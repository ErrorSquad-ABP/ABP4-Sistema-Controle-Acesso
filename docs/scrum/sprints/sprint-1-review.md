# Sprint 1 — Review (21/10, 19h30)

- **Participantes**: ErrorSquad (6) · Prof. Leandro Toss Hoffmann (banca)
- **Goal da sprint**: "Fundação no ar + esqueleto conversando ponta-a-ponta, simulado"
- **Cards concluídos**: **11/13** — US-08 e US-10 seguem para a S2

> Roteiro preparado em 21/10. Feedback do stakeholder e ações devem ser preenchidos durante a review.

## Demos (por card)

| US | O que mostrar | Evidência |
|---|---|---|
| US-01 | Estrutura do monorepo, README, guias, templates, compose | `README.md`, `docs/guides/`, `infra/docker-compose.dev.yml` |
| US-02 | Checks rodando no PR + vínculo Trello↔PR | aba Actions: `ci-backend`, `ci-mobile`, `ci-firmware`, `trello-link` |
| US-03 | Backend em camadas, healthcheck, caso de uso modelo | rota `/health`, `docs/architecture/caso-de-uso-modelo.md` |
| US-04 | Contrato MQTT v1, consumidor e simulador de terminal | `docs/architecture/contratos-mqtt.md`, `npm run sim:terminal` |
| US-05 | Modelo de dados, migration e seed | `docs/architecture/modelo-dados.md`, `backend/prisma/` |
| US-06 | OpenAPI v1 e rotas stub (501) | `docs/api/openapi.yaml`, `GET /api/v1/...` |
| US-07 | Wokwi ao vivo: terminal conecta no Mosquitto, recebe comando e reconecta | serial `[mqtt] conectado e inscrito` + cliente `terminal-dev-01` no broker |
| US-09 | App Flutter com tema do design system | `flutter run`, `mobile/lib/core/` |
| US-10 | Tela de login mock e estados de erro | `flutter run` → `/login` |
| US-11 | Processo, backlog, DoD e sprints | `docs/scrum/` |
| US-12 | Design system e fluxo do usuário | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) · `design/figma/` (23 PNGs) |
| US-13 | Deploy do backend com banco em nuvem | https://abp-4-sistema-controle-acesso.vercel.app/health |

## O que não entra na entrega

- **US-10** — apenas o login mock (PR #13); scanner QR, geolocalização e pt-BR não foram entregues.
- **US-08** — não iniciada (sem branch/PR); começa sobre o esqueleto da US-07, já validado.

## Feedback do stakeholder (professores/focal point)

- _Preencher durante a review._

## Ações (o que vira card no backlog)

- _Preencher durante a review. Candidatos já mapeados na retro:_
  - validar Wokwi↔broker como primeiro passo da S2 (US-07/US-08);
  - fatiar US-10 em login (base da US-27) e scanner/GPS (US-29);
  - estimar o escopo da S2 na Planning 2 (22/10).

## Links

- Repo: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Documento de entrega: [`../../entrega/review-1.md`](../../entrega/review-1.md)
