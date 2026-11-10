# Sprint 2 — Review (11/11, 19h30)

- **Participantes:** ErrorSquad (6) · Prof. Leandro Toss Hoffmann (banca)
- **Goal da sprint:** fluxo QR real ponta-a-ponta, admin na API e deploy seguro
- **Fechamento do trabalho:** 10/11/2026 · **Commit de referência:** `1afd624`
- **Histórias da S2:** **11/13 concluídas** — US-28 e US-29 ficaram para a S3
- **Antecipações da S3:** US-20, US-32, DT-23 e DT-24

> Roteiro preparado em 10/11. Feedback do stakeholder e ações devem ser preenchidos durante a review.

## Demos (por card)

| Card | O que mostrar | Evidência |
|---|---|---|
| US-14 | Login JWT, perfis e bloqueio de rota por perfil | `/auth/login`, `/auth/me`, testes de auth |
| US-15 | CRUD de usuários e proteção do último ADMIN | `/users`, PR #33 |
| US-16/17 | Criar, consultar e cancelar autorização; conflito `409` | `/authorizations`, PR #36 |
| US-18 | `GET /me/authorizations` com status e paginação | contrato em `/docs` |
| US-19 | Token QR `v1.<terminal>.<iat>.<exp>.<hmac>` com 10 s | PR #27, testes de credencial |
| US-20 | Pedido QR dentro e fora de 100 m, evento e comando | [evidência](../../entrega/evidencias/us-20.md), PR #42 |
| US-21 | Histórico de eventos com filtros e decisão gravada | PR #26 |
| US-22 | Display recebendo o QR no Wokwi — publicar status sintético `online` e identificar a simulação (o firmware não envia heartbeat, US-24) | PR #26; demo visual no Wokwi |
| US-26 | Comando `open`, servo e ACK no Wokwi | [evidência](../../entrega/evidencias/us-26-mqtt-servo.md) |
| US-27 | Login real, sessão persistida e logout local | PR #43 |
| US-37 | Worker MQTT com outbox, dedup e relay | código na `main`; deploy no Render **não** comprovado |
| DT-06 | TLS no ESP32 contra o EMQX e negativos de certificado | [evidência](../../entrega/evidencias/dt-06.md) |
| DT-23 | Migration e CHECK de 1–100 m em produção | [evidência](../../entrega/evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot no repositório | [evidência](../../entrega/evidencias/dt-24.md) |

## O que não entra na entrega

- **US-28** (minhas autorizações no app) não foi iniciada; a API está pronta.
- **US-29** (envio do QR e resultado no app) está em review no PR #55, aberto e não integrado: falta validar câmera e GPS em aparelho real.
- **US-22** tem código, sem demonstração visual atual registrada.
- **US-37** tem implementação, sem serviço no Render comprovado.
- **DT-12** e **DT-22** seguem bloqueadas por bancada (câmera/APK e medição de energia).
- NFC, GPS/heartbeat, resiliência local, telas de admin, demo web e diagramas são escopo da S3.

## Feedback do stakeholder (professores/focal point)

- _Preencher durante a review._

## Ações (o que vira card no backlog)

- _Preencher durante a review. Candidatos já mapeados na retro:_
  - fechar US-29 com câmera/GPS reais e US-28 antes de prometer o fluxo no app;
  - concentrar a bancada da US-34 para DT-12, DT-22, NFC e GPS;
  - comprovar o deploy do worker no Render (US-37);
  - registrar demonstração visual do QR (US-22).

## Links

- Repo: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Documento de entrega: [`../../entrega/review-2.md`](../../entrega/review-2.md)
