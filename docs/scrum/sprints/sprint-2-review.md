# Sprint 2 — Review (11/11, 19h30)

- **Participantes:** ErrorSquad (6) · Prof. Leandro Toss Hoffmann (banca)
- **Goal da sprint:** fluxo QR real ponta-a-ponta, admin na API e deploy seguro
- **Fechamento do trabalho:** 10/11/2026 · **Commit de referência do fechamento:** `1afd624` · **estado de 11/11:** `main` em `a0625d7` + telas do app no PR #69
- **Histórias da S2:** **11/13 no fechamento de 10/11** — US-28 e US-29 concluídas em 11/11
- **Antecipações da S3:** US-20, US-32, DT-23 e DT-24; em 11/11 também entraram US-28, US-30, US-31 e US-39

> Roteiro preparado em 10/11 e atualizado em 11/11. Feedback do stakeholder e ações devem ser preenchidos durante a review.

## Demos (por card)

| Card | O que mostrar | Evidência |
|---|---|---|
| US-14 | Login JWT, perfis e bloqueio de rota por perfil | `/auth/login`, `/auth/me`, testes de auth |
| US-15 | CRUD de usuários e proteção do último ADMIN | `/users`, PR #33 |
| US-16/17 | Criar, consultar e cancelar autorização; conflito `409` | `/authorizations`, PR #36 |
| US-18 | `GET /me/authorizations` com status e paginação | contrato em `/docs` |
| US-19 | Token QR `v1.<terminal>.<iat>.<exp>.<hmac>` com 25 s | PR #27, testes de credencial |
| US-20 | Pedido QR dentro e fora de 100 m, evento e comando | [evidência](../../entrega/evidencias/us-20.md), PR #42 |
| US-21 | Histórico de eventos com filtros e decisão gravada | PR #26 |
| US-22 | Display recebendo o QR no Wokwi — publicar status sintético `online` e identificar a simulação (o firmware não envia heartbeat, US-24) | PR #26; demo visual no Wokwi |
| US-26 | Comando `open`, servo e ACK no Wokwi | [evidência](../../entrega/evidencias/us-26-mqtt-servo.md) |
| US-27 | Login real, sessão persistida e logout local | PR #43 |
| US-28 | Minhas autorizações, detalhe e histórico no app | telas no PR #69; 640 testes |
| US-29 | Scanner lendo QR em aparelho, pedido de acesso e resultado liberado/negado | [`us-29-aparelho.md`](../../entrega/evidencias/us-29-aparelho.md), PR #55 |
| US-30 | Administração de autorizações no app (criar, consultar, cancelar) | tela no PR #69 |
| US-31 | Usuários e histórico de acessos no app | tela no PR #69 |
| US-39 | Locais de acesso e cadastro de novo local (raio 1–100 m) | tela e API; cadastro conferido no PostgreSQL |
| US-37 | Worker MQTT com outbox, dedup e relay **LIVE** no Render | [`us-37.md`](../../entrega/evidencias/us-37.md) |
| DT-06 | TLS no ESP32 contra o EMQX e negativos de certificado | [evidência](../../entrega/evidencias/dt-06.md) |
| DT-23 | Migration e CHECK de 1–100 m em produção | [evidência](../../entrega/evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot no repositório | [evidência](../../entrega/evidencias/dt-24.md) |

## O que não entra na entrega

- **US-22** tem código, sem demonstração visual atual registrada no display do terminal.
- **Servo/cancela física** não está implementado; o NFC tem evidência física inicial com servo desabilitado.
- **US-24** (heartbeat) e **US-25** (resiliência offline) seguem pendentes.
- **APK de release em loja** não entrou; a execução em aparelho usou APK debug.
- **DT-22** segue bloqueada por bancada (medição de energia).
- **US-33** (revisão de segurança), **US-35** (diagramas) e **US-36** (relatório ABNT/apresentação) são da janela final.
- O fluxo completo app → terminal real e a abertura física não foram demonstrados.

## Feedback do stakeholder (professores/focal point)

- _Preencher durante a review._

## Ações (o que vira card no backlog)

- _Preencher durante a review. Candidatos já mapeados na retro:_
  - fechar a bancada da US-34 para servo/cancela, DT-22, heartbeat (US-24) e offline (US-25);
  - registrar demonstração visual do QR no display do terminal (US-22);
  - concluir US-33 (segurança), US-35 (diagramas) e US-36 (relatório ABNT);
  - validar a continuidade do worker no Render além da observação pontual de 11/11.

## Links

- Repo: https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso
- Board: https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm
- Documento de entrega: [`../../entrega/review-2.md`](../../entrega/review-2.md)
