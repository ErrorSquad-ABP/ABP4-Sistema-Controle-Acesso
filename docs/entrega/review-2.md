# Review 2 — Documento de entrega · Sprint 2

## 1. Identificação, equipe e links

- **Curso:** Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí.
- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso.
- **Equipe:** ErrorSquad — João Victor Lopes Rosa (SM), Felipe Pacheco (PO), Carlos Santo, Caio Araujo, Leo Silva e Arthur Facchinetti.
- **Sprint 2:** 22/10 a 11/11/2026 · **Review:** 11/11/2026, 19h30 · **fechamento do trabalho: 10/11/2026**.
- **Referência da entrega:** branch `main`, commit `1afd624`.

| Referência | Link |
|---|---|
| Repositório | [ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso) |
| Board | [ErrorSquad ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm) |
| Design | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) |
| API publicada | [/health](https://abp-4-sistema-controle-acesso.vercel.app/health) · [/docs](https://abp-4-sistema-controle-acesso.vercel.app/docs) |

## 2. Objetivo e resultado

**Objetivo:** fluxo QR real ponta-a-ponta, backend administrativo, app consumindo o contrato e operação com deploy seguro.

A sprint entregou o **fluxo QR real no backend** (credencial de 25 s, decisão, consumo condicional da autorização, evento auditado e comando MQTT), o **admin de usuários e autorizações na API**, o **login real com sessão no app**, o **worker MQTT com outbox/dedup/relay** e um conjunto de **endurecimentos de entrega** (migrations no CD, seed protegida, TLS no firmware, CORS, teto de 100 m, Actions por SHA e Dependabot).

O time tinha folga no fim da sprint e **antecipou trabalho da S3**: US-20, US-32, DT-23 e DT-24, além de absorver 22 das 24 dívidas técnicas. O encerramento foi feito em **10/11**, um dia antes da data prevista, sem antecipar a cerimônia de Review.

**O resultado é um fluxo de acesso real no servidor e no terminal, não um aplicativo completo:** o app lê o QR, mas **ainda não envia o pedido de acesso** (US-29 está em review no PR #55, ainda não integrado) e as telas de autorizações/admin do app não existem (US-28, US-30, US-31). NFC, GPS/heartbeat e resiliência local do terminal também não entraram.

| Indicador | Resultado no fechamento |
|---|---|
| Histórias da S2 concluídas | **11/13** — US-28 e US-29 ficaram para a S3 |
| Antecipações da S3 | US-20, US-32, DT-23 e DT-24 |
| Cards no board | **48 concluídos** de 63 (26 US + 22 DT); 13 abertos e 2 bloqueados |
| PRs mergeados na S2 | **28** — #26 a #65, incluindo documentação |
| Testes de backend | **458** em 53 arquivos, com PostgreSQL e seed |
| Testes de mobile na `main` | **93** (a US-29, ainda não integrada, leva a 215 no PR #55) |
| Firmware | 12 executáveis host + 6 cenários de timing; builds padrão e com TLS |
| E2E de acesso | **29/29** na execução registrada; o CD da `main` também roda o cenário |
| Integração contínua | 6 checks obrigatórios + CodeQL; Dependabot semanal ativo |
| Deploy registrado | API Vercel `2dd532b`, Neon `database: ok`, migration da DT-23 aplicada |
| Banco de produção | `AccessLocation_radiusMeters_check` (1–100) confirmada em 10/11 |

A S2 não teve estimativa por pontos registrada; os números não representam velocidade por pontos. Os totais de teste são do fechamento, não uma nova execução deste documento.

## 3. O que está no ar

- **API na Vercel:** `/health` responde `status: ok`, `database: ok`, `version: 2dd532b`. O contrato está em `/docs` e `/openapi.json`.
- **Autenticação e autorização:** login JWT com perfis ADMIN/RESIDENT/VISITOR, rate limit, CRUD de usuários, criação/consulta/cancelamento de autorizações e `GET /me/authorizations`.
- **QR real:** `POST /api/v1/access-events/qr` valida token assinado de 25 s, terminal, credencial, vigência, usos, local e distância (mínimo entre o raio do local e **100 m**), grava o evento e publica o comando de abertura. Negativa é `200` com `decision: DENIED`, não erro HTTP.
- **Banco:** Neon com migrations aplicadas pelo CD; a CHECK de 1–100 m existe em produção.
- **MQTT:** worker com outbox persistente, relay em janela econômica (18:45–23:05), deduplicação com TTL de 24 h e ACK correlacionado. **O deploy no Render não foi observado**; a implementação está na `main`.
- **Mobile:** login real, sessão persistida em Keystore, logout local e scanner que lê o QR e obtém posição. **Não envia o pedido de acesso** e não publica APK em loja.
- **Firmware:** display do QR, servo, LEDs, buzzer, ACK e recusa por prazo/dedup; **TLS com CA embutido validado no ESP32 real contra o EMQX** (conexão e negativos de CA/hostname). Servo/PWM e ACK ficaram pendentes de bancada.
- **Qualidade de entrega:** Actions pinadas por SHA completo, Dependabot semanal (Actions, npm e pub), migrations no CD, seed de demonstração protegida e E2E no CI.

## 4. Entregas por card — escopo da S2

| Card | Entrega efetiva | Evidência no repositório |
|---|---|---|
| US-14 | Auth JWT, perfis e RBAC; sem refresh/logout no servidor | [`auth/`](../../backend/src/), PR #26 |
| US-15 | CRUD de usuários com desativação lógica e proteção do último ADMIN | [`users`](../../backend/src/), PR #33 |
| US-16 | Criação de autorização com intervalo, usos e validações | [`authorizations`](../../backend/src/), PR #36 |
| US-17 | Consulta com filtros/status e cancelamento com motivo; 409 em conflito | PR #36, [DT-17](evidencias/dt-17.md) |
| US-18 | `GET /me/authorizations` paginado com status calculado | PR #33 |
| US-19 | Credencial QR assinada `v1.<terminal>.<iat>.<ttl>.<hmac>`, validade de 25 s | [`qr-credential`](../../backend/src/), PR #27 |
| US-21 | Consulta de eventos e histórico com filtros; gravação QR/NFC simulado | PR #26, [DT-01/02/03](evidencias/dt-01-02-03.md) |
| US-22 | Render do QR no display com cache por token e status | PR #26; demonstração visual pendente |
| US-26 | Comando `open`/`deny` via MQTT com ACK e servo | [evidência](evidencias/us-26-mqtt-servo.md) |
| US-27 | Login real, sessão persistida e encerramento local | PR #43 |
| US-28 | **Não entregue** — tela "minhas autorizações" no app | — |
| US-29 | **Em review** — PR #55 aberto, ainda não integrado; falta câmera/GPS em aparelho | [PR #55](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pull/55) |
| US-37 | Worker MQTT no Render; implementação presente, **deploy não comprovado** | PR #26, [`deploy.md`](../guides/deploy.md) |

## 5. Antecipações da S3

Trabalho com **Sprint alvo S3** que foi concluído na S2 por folga do time:

| Card | Entrega | Evidência |
|---|---|---|
| US-20 | Decisão de acesso QR real, evento auditado e geofence de 100 m | [evidência](evidencias/us-20.md), PR #42 |
| US-32 | E2E simulado no CI (PostgreSQL e broker temporários) | PR #32, [guia de desenvolvimento](../guides/desenvolvimento.md) |
| DT-23 | Teto de 100 m na política e CHECK de 1–100 m no banco, implantados | [evidência](evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot semanal, ativos na `main` | [evidência](evidencias/dt-24.md) |

Além dessas, **22 das 24 dívidas técnicas** estão concluídas, incluindo TLS no firmware (DT-06), CORS (DT-08), APK no CI (DT-10), migrations no CD (DT-09), retenção de comandos (DT-18), prazos da deduplicação (DT-16) e janela do relay (DT-21). Ficaram abertas apenas **DT-12** e **DT-22**, ambas dependentes de bancada.

## 6. Qualidade e reprodução da demo

### Preparação

Usar a `main` de referência, dependências instaladas e os ambientes do [guia local](../guides/como-rodar.md), do [README mobile](../../mobile/README.md) e do [README firmware](../../firmware/README.md). Para o QR real, é preciso um terminal com credencial válida e um usuário com autorização vigente na seed de demonstração.

### Roteiro

1. **API publicada:** abrir `/health` (`database: ok`, versão `2dd532b`) e `/docs`; mostrar que o contrato e a implementação são o mesmo artefato gerado.
2. **Login e autorizações:** autenticar com a conta demo, criar uma autorização com janela e usos e consultar `GET /me/authorizations`. Mostrar que um usuário sem autorização recebe lista vazia, não erro.
3. **QR real:** gerar o QR assinado do terminal (US-19) e chamar `POST /api/v1/access-events/qr` com posição dentro e fora de 100 m. Mostrar `GRANTED` com evento e comando, e `DENIED` com `OUT_OF_RANGE` fora do raio. Repetir com o mesmo `requestId` e mostrar que a autorização **não** é consumida duas vezes.
4. **Terminal:** no Wokwi, mostrar o display recebendo o QR, o comando `open`, o servo e o ACK `executed`. O worker só publica QR para terminal considerado `online`, e o firmware atual **não envia heartbeat** (US-24); a demo precisa publicar status sintético (ou usar o simulador) e **identificar isso como simulação**. No hardware, mostrar a evidência já registrada de TLS com o EMQX; **não** prometer servo/ACK em bancada nesta demo.
5. **App:** mostrar login real, persistência de sessão e o scanner lendo QR + posição. Explicitar que o envio do pedido ao backend **não** faz parte desta entrega (US-29 em review).
6. **Qualidade:** abrir a aba Actions e mostrar os 6 checks obrigatórios, CodeQL e o Dependabot; mostrar a migration da DT-23 aplicada no Neon e a constraint ativa.

**São provas separadas:** a API demonstra decisão e persistência; o Wokwi demonstra transporte e atuação; o hardware comprova TLS; o app demonstra login e leitura, sem liberar acesso. Nenhuma delas, isolada, prova o fluxo completo em campo.

## 7. O que não entrou e por quê

**Encerrar a sprint não significa 13/13.** Duas histórias do escopo da S2 ficaram para a S3, por dependência de trabalho de app e de hardware:

- **US-28 (minhas autorizações no app):** não iniciada; a API está pronta desde a US-18.
- **US-29 (envio do QR e resultado no app):** PR #55 aberto em review, com CI verde e o P1 da revisão corrigido, mas **câmera e GPS reais não validados**. O provider do scanner foi corrigido para não enviar pedido após sair da tela; restam os testes físicos.
- **US-22 (demonstração visual do QR):** código presente e usado pelo worker, mas a demonstração visual atual não foi registrada.
- **US-37 (worker no Render):** implementação e blueprint presentes; **sem evidência de serviço no ar**.

Fora do escopo da S2 e mantidas para a S3: US-23 (NFC), US-24 (GPS/heartbeat), US-25 (resiliência local), US-30/31 (admin no app), US-33 (revisão de segurança), US-34 (hardware), US-35 (diagramas), US-38 (demo web) e US-39 (cadastro de locais). **DT-12** e **DT-22** seguem bloqueadas por bancada; a DT-22 tem decisão e orçamento documentados, mas nenhuma corrente medida.

## 8. Dívida técnica e prioridades da S3

| Situação | Cards |
|---|---|
| Concluídas na S2 | DT-01 a DT-11, DT-13 a DT-21, DT-23, DT-24 |
| Bloqueadas por hardware | **DT-12** (câmera real + APK em aparelho) e **DT-22** (corrente e 24 h de continuidade) |
| Prioridade da S3 | Fechar DT-12/DT-22 na US-34; concluir US-29 (câmera/GPS) e US-28 antes de prometer o fluxo no app |

## 9. Riscos

| Risco | Tratamento |
|---|---|
| Confundir backend QR pronto com fluxo no app | US-29 não integrada e US-28 pendente; a demo separa as provas |
| `/health` verde mascarar integração incompleta | O smoke test cobre só API e banco; Render, app e hardware têm evidências próprias |
| Worker no Render sem deploy comprovado | Validar serviço, log de conexão MQTT e `/healthz` na S3 |
| Hardware atrasar NFC/GPS/câmera/energia | Concentrar a bancada na US-34; não declarar medições ou leituras não feitas |
| Migrations em produção | CD aplica migration antes do deploy; pré-check da DT-23 feito e registrado |
| Dependabot abrir PRs e alguém mergear sem review | Atualização é PR normal, com CI e revisão; sem auto-merge |
| Fechamento antecipado virar promessa de 100% | Este documento declara 11/13 na S2 e o carry-over explícito |

## 10. Próxima sprint

A **S3 ocorre de 12/11 a 25/11/2026**, com Review em 25/11 às 19h30. O foco é fechar o que falta do controle de acesso: NFC (US-23), GPS/heartbeat (US-24), resiliência do terminal (US-25), telas de autorizações e admin no app (US-28/30/31), scanner com resultado (US-29), revisão de segurança (US-33), hardware (US-34), diagramas (US-35), demo web (US-38) e cadastro de locais (US-39). O relatório ABNT e a apresentação (US-36) ficam para a janela de entrega final.

**Dependência crítica:** US-23/24/25/29/34 e DT-12/DT-22 dependem de bancada. Sem isso, a S3 fecha o software, mas não consegue declarar o aceite físico.

## 11. Rastreabilidade

- [Product backlog e critérios de aceite](../scrum/product-backlog.md).
- [Fechamento da Sprint 2](../scrum/sprints/sprint-2.md) · [roteiro da Review 2](../scrum/sprints/sprint-2-review.md) · [retrospectiva](../scrum/sprints/sprint-2-retro.md).
- [Definition of Done](../scrum/definition-of-done.md).
- [Matriz de requisitos](matriz-requisitos.md) e [índice de evidências](README.md).
- Evidências por card em [`evidencias/`](evidencias/); destaques: [US-20](evidencias/us-20.md), [DT-01/02/03](evidencias/dt-01-02-03.md), [DT-06](evidencias/dt-06.md), [DT-08](evidencias/dt-08.md), [DT-23](evidencias/dt-23.md) e [DT-24](evidencias/dt-24.md).
- Rastreio: card `US-XX`/`DT-XX` → branch → linha `Card:` do PR → checks e merge. [PRs do projeto](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pulls?q=is%3Apr+is%3Amerged).

> **Nota de conferência:** no commit `1afd624` estão **28 PRs mergeados** desde a S1 (#26 a #65). Os números de teste foram coletados em 10/11: backend 458/458 (53 arquivos, PostgreSQL + seed) e mobile 93/93 na `main`.
