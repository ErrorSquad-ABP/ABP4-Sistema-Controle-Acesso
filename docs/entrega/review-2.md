# Review 2 — Documento de entrega · Sprint 2

## 1. Identificação, equipe e links

- **Curso:** Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí.
- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso.
- **Equipe:** ErrorSquad — João Victor Lopes Rosa (SM), Felipe Pacheco (PO), Carlos Santo, Caio Araujo, Leo Silva e Arthur Facchinetti.
- **Sprint 2:** 22/10 a 11/11/2026 · **Review:** 11/11/2026, 19h30 · **estado atualizado em 11/11/2026**.
- **Referência da entrega:** branch `main`, commit `a0625d7`.

| Referência | Link |
|---|---|
| Repositório | [ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso) |
| Board | [ErrorSquad ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm) |
| Design | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) |
| API publicada | [/health](https://abp-4-sistema-controle-acesso.vercel.app/health) · [/docs](https://abp-4-sistema-controle-acesso.vercel.app/docs) |
| Apresentação (10–15 min) | [Roteiro e capturas](apresentacao-sprint2/README.md) · PDF 16:9 e PPTX gerados localmente por `python docs/entrega/apresentacao-sprint2/gerar.py` (não versionados) |

## 2. Objetivo e resultado

**Objetivo:** fluxo QR real ponta-a-ponta, backend administrativo, app consumindo o contrato e operação com deploy seguro.

A sprint entregou o **fluxo QR real no backend e no app** (credencial de 25 s, pedido autenticado, resultado `GRANTED`/`DENIED`, consumo condicional da autorização, evento auditado e comando MQTT), o **admin de usuários e autorizações na API**, o **login real com sessão no app**, o **worker MQTT com outbox/dedup/relay** e um conjunto de **endurecimentos de entrega** (migrations no CD, seed protegida, TLS no firmware, CORS, teto de 100 m, Actions por SHA e Dependabot).

Além de absorver 22 das 24 dívidas técnicas, a S2 **antecipou trabalho da S3**: US-20, US-32, DT-23, DT-24 e a integração de software da **US-23 (NFC RC522)** em 11/11. A US-23 permanece **Em review no Trello**; integração não equivale a aceite físico final.

**O app envia o pedido e mostra o resultado:** a US-29 (PR #55) e o QR de 25 s (PR #64) já estavam integrados em 10/11. O app real tem login, sessão, Home e scanner com resultado; **não** tem a lista de autorizações (US-28) nem admin (US-30/31). GPS/heartbeat do terminal (US-24) e resiliência offline (US-25) seguem pendentes. A demo local usa câmera e posição sintéticas e não comprova o fluxo físico app → ESP32 → servo.

| Indicador | Resultado no fechamento |
|---|---|
| Histórias da S2 concluídas no quadro | **12/13** — resta US-28; ressalva de comprovação em US-22 |
| Antecipações da S3 | US-20, US-32, DT-23, DT-24; software US-23 integrado, card em review |
| Cards no board | **49 em listas concluídas** de 63 (27 US + 22 DT), **1 em review** (US-23), 1 em andamento, 10 na Sprint 3 e 2 bloqueados |
| Integração em 11/11 | PR #68 (Supertest), merge `4152809`; PR #67 (NFC), merge `a0625d7`, com correção `00ed519`; nenhum PR aberto na consulta |
| Testes de backend no CI da `main` | **460/460** em 53 arquivos, com PostgreSQL e seed; local padrão: 420 aprovados e 40 condicionais a banco pulados |
| Mobile | **215/215**, analyze limpo e build web aprovado em 11/11 |
| Firmware | Suíte host completa aprovada, incluindo 8 cenários de timing (3 fases + PUBACK, com TLS 0/1); builds físico, Wokwi e TLS/OLED aprovados |
| E2E de acesso | **31/31**, com PostgreSQL e broker temporários |
| Integração contínua | 6 checks obrigatórios + CodeQL; Dependabot semanal ativo |
| Deploy registrado em 11/11 | API Vercel `a0625d7`, `database: ok`; CD da `main` aprovado; worker MQTT `live` no Render com `mqtt conectado` e `/healthz` ok |
| Banco de produção | `AccessLocation_radiusMeters_check` (1–100) confirmada em 10/11 |

A S2 não teve estimativa por pontos registrada; os números não representam velocidade por pontos. Os totais vêm das verificações informadas para 11/11, não de uma nova execução deste documento. A consulta completa ao Trello distingue **49 em listas concluídas + 1 em review**: 50 cards têm flag `complete`, mas essa flag não muda a lista da US-23.

## 3. O que está publicado e integrado

- **API na Vercel:** `/health` respondeu em 11/11 com `status: ok`, `database: ok`, `version: a0625d7`. O contrato está em `/docs` e `/openapi.json`.
- **Autenticação e autorização:** login JWT com perfis ADMIN/RESIDENT/VISITOR, rate limit, CRUD de usuários, criação/consulta/cancelamento de autorizações e `GET /me/authorizations`.
- **QR real:** `POST /api/v1/access-events/qr` valida token assinado de 25 s, terminal, credencial, vigência, usos, local e distância (mínimo entre o raio do local e **100 m**), grava o evento e publica o comando de abertura. Negativa é `200` com `decision: DENIED`, não erro HTTP.
- **Banco:** Neon com migrations aplicadas pelo CD; a CHECK de 1–100 m existe em produção.
- **MQTT:** worker com outbox persistente, relay em janela econômica (18:45–23:05), deduplicação com TTL de 24 h e ACK correlacionado. O worker está no ar no Render (`abp4-mqtt-worker`, plano free) desde 11/11, conectado ao EMQX por TLS e com `/healthz` ok; resta comprovar o ciclo completo com terminal físico. Ver [`us-37.md`](evidencias/us-37.md).
- **Mobile integrado:** login real, sessão persistida em Keystore no Android, Home, logout local e scanner que lê QR, obtém posição, envia o pedido e mostra liberação/negativa. Não há publicação em loja nem demo web publicada (US-38).
- **Firmware integrado:** display do QR, servo, LEDs, buzzer, ACK, recusa por prazo/dedup e NFC RC522. **TLS com CA embutido foi validado no ESP32 real contra o EMQX**. A evidência NFC anterior correlaciona negativas/liberações e ACKs, com **servo desligado**: ACK confirma feedback, não abertura. A revisão de 11/11 adiou o ACK QoS 1 até `idle` para não bloquear o ciclo da porta; passou em host/build, **sem nova gravação física**.
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
| US-21 | Consulta de eventos e histórico com filtros; gravação QR/NFC, com leitor integrado pela US-23 | PR #26, [DT-01/02/03](evidencias/dt-01-02-03.md), PR #67 |
| US-22 | Render do QR no display com cache por token e status | PR #26; demonstração visual pendente |
| US-26 | Comando `open`/`deny` via MQTT com ACK e servo | [evidência](evidencias/us-26-mqtt-servo.md) |
| US-27 | Login real, sessão persistida e encerramento local | PR #43 |
| US-28 | **Não entregue** — tela "minhas autorizações" no app | — |
| US-29 | **Integrada e validada no aparelho** — pedido QR e resultado no app, câmera e GPS reais em 11/11; falta build release e ambiente de produção na US-34/DT-12 | [PR #55](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pull/55), [evidência](evidencias/us-29.md), [aparelho](evidencias/us-29-aparelho.md) |
| US-37 | Worker MQTT no Render; serviço `live` em 11/11 com MQTT TLS e `/healthz` ok | PR #26, [`deploy.md`](../guides/deploy.md), [`us-37.md`](evidencias/us-37.md) |

## 5. Antecipações da S3

Trabalho com **Sprint alvo S3** antecipado na S2, preservando a ressalva de review da US-23:

| Card | Entrega | Evidência |
|---|---|---|
| US-20 | Decisão de acesso QR real, evento auditado e geofence de 100 m | [evidência](evidencias/us-20.md), PR #42 |
| US-23 | Leitor NFC RC522, MQTT QoS 1, decisão e feedback; software integrado, card **Em review**, sem aceite físico final da revisão | [evidência](evidencias/us-23-nfc-rc522.md), PR #67 |
| US-32 | E2E simulado no CI (PostgreSQL e broker temporários) | PR #32, [guia de desenvolvimento](../guides/desenvolvimento.md) |
| DT-23 | Teto de 100 m na política e CHECK de 1–100 m no banco, implantados | [evidência](evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot semanal, ativos na `main` | [evidência](evidencias/dt-24.md) |

Além dessas, **22 das 24 dívidas técnicas** estão concluídas, incluindo TLS no firmware (DT-06), CORS (DT-08), APK no CI (DT-10), migrations no CD (DT-09), retenção de comandos (DT-18), prazos da deduplicação (DT-16) e janela do relay (DT-21). Ficaram abertas apenas **DT-12** e **DT-22**, ambas dependentes de bancada.

## 6. Qualidade e reprodução da demo

### Preparação

Usar a `main` de referência, dependências instaladas e os ambientes do [guia local](../guides/como-rodar.md), do [README mobile](../../mobile/README.md) e do [README firmware](../../firmware/README.md). Para o QR real, é preciso um terminal com credencial válida e um usuário com autorização vigente na seed de demonstração. Não exibir segredos nas capturas.

**Ambiente das capturas de 11/11:** PostgreSQL 17 em Docker isolado (`5448`), Mosquitto (`1888`), API Express (`3012`), worker em processo separado e Flutter web (`5012`), sem alteração do produto. O Chromium usou câmera fake Y4M com QR assinado e geolocalização sintética. API, banco e decisor são reais; terminal, status `online` e ACKs são simulados. Fonte: [`execucao-local.json`](apresentacao-sprint2/capturas/execucao-local.json) e capturas no [roteiro da apresentação](apresentacao-sprint2/README.md).

### Roteiro

1. **Contexto e limites (1–2 min):** objetivo, 12/13 no quadro e distinção entre software integrado, simulação e aceite físico. Usar os 12 slides 16:9 do material de apoio; não há hardware disponível para esta review.
2. **App real (4 min):** capturas de login, Home e telas de acesso liberado/negado. Explicar a leitura pelo scanner e o pedido autenticado à API local real, com QR válido de 25 s e posição sintética dentro/fora de 100 m.
3. **Decisão e rastreio (3 min):** mostrar os eventos do banco e comandos MQTT; o replay do mesmo `requestId` retorna o mesmo evento sem consumo extra. NFC autorizado da seed e desconhecido também passaram pelo worker/decisor reais, com ACKs do simulador.
4. **Terminal e evidência anterior (1–2 min):** explicar RC522 e correção do ACK adiado até `idle`. Mostrar a evidência física anterior de negativa/liberação/feedback com servo desligado; não apresentar a captura local como ESP32 conectado. Sem heartbeat físico (US-24), a demo usa status `online` sintético identificado.
5. **Qualidade e operação (1–2 min):** API pública `a0625d7`/banco ok e Actions aprovadas; não confundir worker local com deploy no Render nem build web local com US-38 publicada.
6. **Pendências e próximos passos (1–2 min):** US-28, GPS/heartbeat, offline, admin e bancada. Reservar o restante da janela de 10–15 min para perguntas, ajustando o tempo dos blocos.

**São provas complementares:** capturas do APK em aparelho físico (câmera e GPS reais), decisão e persistência locais, transporte/ACK do terminal simulado e evidência física anterior do ESP32. Não há demonstração do servo em movimento nesta review, e o terminal que exibiu o QR foi o simulador.

**Execuções de 11/11 aprovadas:** [CD backend 43046423006](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/runs/43046423006), [CI backend 43046423082](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/runs/43046423082), [firmware 43046423239](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/runs/43046423239) e [CodeQL 43046422439](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/actions/runs/43046422439).

## 7. O que não entrou e por quê

**Encerrar a sprint não significa 13/13 nem 100% de aceite físico.** Uma história do escopo da S2 segue para a S3, além das ressalvas de comprovação:

- **US-28 (minhas autorizações no app):** não iniciada; a API está pronta desde a US-18.
- **US-29 (integrada):** envio do QR e resultado funcionam no app, e em 11/11 o fluxo rodou no aparelho com **câmera e GPS reais** (6,8 m liberado, 1.207,9 m negado). Faltam build release e execução contra a API de produção na US-34/DT-12.
- **US-22 (demonstração visual do QR):** código presente e usado pelo worker, mas a demonstração visual atual não foi registrada.
- **US-37 (worker no Render):** serviço no ar desde 11/11, com `mqtt conectado`, assinatura dos três filtros e `/healthz` ok; falta o ciclo com terminal físico.

Da S3, a US-23 (NFC) teve o software antecipado e integrado, mas continua em review e requer aceite da revisão em bancada. Permanecem US-24 (GPS/heartbeat), US-25 (resiliência local), US-30/31 (admin no app), US-33 (revisão de segurança), US-34 (hardware), US-35 (diagramas), US-38 (demo web) e US-39 (cadastro de locais). **DT-12** e **DT-22** seguem bloqueadas por bancada; a DT-22 tem decisão e orçamento documentados, mas nenhuma corrente medida.

## 8. Dívida técnica e prioridades da S3

| Situação | Cards |
|---|---|
| Concluídas na S2 | DT-01 a DT-11, DT-13 a DT-21, DT-23, DT-24 |
| Bloqueadas por hardware | **DT-12** (câmera real + APK em aparelho) e **DT-22** (corrente e 24 h de continuidade) |
| Prioridade da S3 | Fechar DT-12/DT-22 na US-34, validar fisicamente a US-29 e a revisão NFC; implementar US-28 |

## 9. Riscos

| Risco | Tratamento |
|---|---|
| Confundir app integrado com aceite físico | US-29 validada no aparelho (câmera/GPS reais), mas com APK debug e API local; release e produção seguem na US-34 |
| `/health` verde mascarar integração incompleta | O smoke test cobre só API e banco; Render, app e hardware têm evidências próprias |
| Worker no Render reiniciar ou dormir | Self-ping a cada 10 min; conferir `/healthz` e o log de reconexão após spin-down |
| Hardware atrasar aceite NFC/GPS/câmera/energia | Concentrar a bancada na US-34; a revisão NFC integrada não foi regravada nem medida na placa |
| Migrations em produção | CD aplica migration antes do deploy; pré-check da DT-23 feito e registrado |
| Dependabot abrir PRs e alguém mergear sem review | Atualização é PR normal, com CI e revisão; sem auto-merge |
| Contagem de cards virar promessa de 100% | Declarar 12/13 no quadro, US-28 pendente e ressalvas físicas/deploy; US-23 fica em review |

## 10. Próxima sprint

A **S3 ocorre de 12/11 a 25/11/2026**, com Review em 25/11 às 19h30. O foco é fechar o que falta do controle de acesso: aceite físico da revisão NFC (US-23), GPS/heartbeat (US-24), resiliência do terminal (US-25), telas de autorizações e admin no app (US-28/30/31), validação física do scanner já integrado (US-29, via US-34/DT-12), revisão de segurança (US-33), hardware (US-34), diagramas (US-35), demo web (US-38) e cadastro de locais (US-39). O relatório ABNT e a apresentação final (US-36) ficam para a janela de entrega final; o material desta review não fecha esse card.

**Dependência crítica:** US-23/24/25/29/34 e DT-12/DT-22 dependem de bancada. Sem isso, a S3 fecha o software, mas não consegue declarar o aceite físico.

## 11. Rastreabilidade

- [Product backlog e critérios de aceite](../scrum/product-backlog.md).
- [Fechamento da Sprint 2](../scrum/sprints/sprint-2.md) · [roteiro da Review 2](../scrum/sprints/sprint-2-review.md) · [retrospectiva](../scrum/sprints/sprint-2-retro.md).
- [Definition of Done](../scrum/definition-of-done.md).
- [Matriz de requisitos](matriz-requisitos.md) e [índice de evidências](README.md).
- Evidências por card em [`evidencias/`](evidencias/); destaques: [US-20](evidencias/us-20.md), [DT-01/02/03](evidencias/dt-01-02-03.md), [DT-06](evidencias/dt-06.md), [DT-08](evidencias/dt-08.md), [DT-23](evidencias/dt-23.md) e [DT-24](evidencias/dt-24.md).
- Rastreio: card `US-XX`/`DT-XX` → branch → linha `Card:` do PR → checks e merge. [PRs do projeto](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pulls?q=is%3Apr+is%3Amerged).

> **Corte intermediário preservado (10/11, `1afd624`):** o registro anterior contabilizava 11/13 histórias da S2, US-28/29 como carry-over, 48/63 cards (26 US + 22 DT), 28 PRs e testes backend 458/mobile 93. Era um retrato intermediário, não o fechamento atualizado: PR #55 (US-29) e PR #64 (QR de 25 s) já foram integrados em 10/11; para a review de 11/11 valem os estados e evidências acima.
