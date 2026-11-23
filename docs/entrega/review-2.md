# Review 2 — Documento de entrega · Sprint 2

## 1. Identificação, equipe e links

- **Curso:** Desenvolvimento de Software Multiplataforma (4DSM) — FATEC Jacareí.
- **Projeto:** ABP 2026-2 · Sistema Integrado de Controle de Acesso.
- **Equipe:** ErrorSquad — João Victor Lopes Rosa (SM), Felipe Pacheco (PO), Carlos Santo, Caio Araujo, Leo Silva e Arthur Facchinetti.
- **Sprint 2:** 22/10 a 11/11/2026 · **Review:** 11/11/2026, 19h30 · **fechamento do trabalho: 10/11/2026**, com atualização em 11/11.
- **Referência da entrega:** branch `main`, commit `a0625d7`; as telas do app e o cadastro de locais estão no PR #69.

| Referência | Link |
|---|---|
| Repositório | [ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso) |
| Board | [ErrorSquad ABP 4DSM](https://trello.com/b/AxZZyPyN/errorsquad-abp-4dsm) |
| Design | [Figma](https://www.figma.com/design/nddGhlwJIi5rMzhvsK5Rkl) |
| API publicada | [/health](https://abp-4-sistema-controle-acesso.vercel.app/health) · [/docs](https://abp-4-sistema-controle-acesso.vercel.app/docs) |

## 2. Objetivo e resultado

**Objetivo:** fluxo QR real ponta-a-ponta, backend administrativo, app consumindo o contrato e operação com deploy seguro.

A sprint entregou o **fluxo QR real no backend** (credencial de 25 s, decisão, consumo condicional da autorização, evento auditado e comando MQTT), o **admin de usuários e autorizações na API**, o **login real com sessão no app**, o **worker MQTT com outbox/dedup/relay** e um conjunto de **endurecimentos de entrega** (migrations no CD, seed protegida, TLS no firmware, CORS, teto de 100 m, Actions por SHA e Dependabot). Em 11/11, o app recebeu as **12 telas do Figma**, o shell de abas, as telas de autorizações/perfil/locais e a administração de autorizações e de usuários (US-28/29/30/31/39).

O time tinha folga no fim da sprint e **antecipou trabalho da S3**: US-20, US-32, DT-23 e DT-24, além de absorver 22 das 24 dívidas técnicas. O encerramento foi feito em **10/11**, um dia antes da data prevista, sem antecipar a cerimônia de Review.

**O resultado é um fluxo de acesso real no servidor e no terminal, com o app completo nas telas previstas:** o app lê o QR, envia o pedido e mostra liberado/negado (US-29), tem as 12 telas do Figma e o shell de abas, e cobre autorizações, perfil, locais (US-39) e administração (US-30/31). A execução em aparelho físico foi registrada em [`us-29-aparelho.md`](evidencias/us-29-aparelho.md). O que continua fora é o **físico**: servo/cancela não implementados, heartbeat (US-24) e resiliência offline (US-25) pendentes, e o fluxo app → terminal real não demonstrado.

| Indicador | Resultado em 11/11 |
|---|---|
| Histórias da S2 | **11/13 no fechamento de 10/11**; US-28 e US-29 concluídas em 11/11 |
| Antecipações da S3 | US-20, US-32, DT-23 e DT-24; em 11/11, US-30, US-31 e US-39 |
| Cards no board | 48 concluídos de 63 no fechamento de 10/11; US-28/30/31/39 passaram a Concluído em 11/11 (contagem viva no Trello) |
| PRs mergeados na S2 | 28 no fechamento (#26 a #65); depois entraram #67 e #68, e o PR #69 traz o app |
| Testes de backend | **433 aprovados + 40 pulados** em 11/11 |
| Testes de mobile | **640** em 11/11 (93 na `main` no fechamento de 10/11) |
| Firmware | 12 executáveis host + 6 cenários de timing; builds padrão e com TLS; NFC RC522 na US-23 |
| E2E de acesso | **29/29** na execução registrada em 10/11 |
| Integração contínua | 6 checks obrigatórios + CodeQL; Dependabot semanal ativo |
| Deploy registrado | API Vercel `a0625d7`, Neon `database: ok`; worker LIVE no Render |
| Banco de produção | `AccessLocation_radiusMeters_check` (1–100) confirmada em 10/11 |

A S2 não teve estimativa por pontos registrada; os números não representam velocidade por pontos. Os totais de teste são das execuções registradas em 10/11 e 11/11, não uma nova execução deste documento.

## 3. O que está no ar

- **API na Vercel:** `/health` responde `status: ok`, `database: ok`, `version: a0625d7`. O contrato está em `/docs` e `/openapi.json`.
- **Autenticação e autorização:** login JWT com perfis ADMIN/RESIDENT/VISITOR, rate limit, CRUD de usuários, edição do próprio nome (`PATCH /me`), criação/consulta/cancelamento de autorizações, `GET /me/authorizations` e cadastro/listagem de locais (`GET`/`POST /locations`).
- **QR real:** `POST /api/v1/access-events/qr` valida token assinado de 25 s, terminal, credencial, vigência, usos, local e distância (mínimo entre o raio do local e **100 m**), grava o evento e publica o comando de abertura. Negativa é `200` com `decision: DENIED`, não erro HTTP.
- **Banco:** Neon com migrations aplicadas pelo CD; a CHECK de 1–100 m existe em produção.
- **MQTT:** worker com outbox persistente, relay em janela econômica (18:45–23:05), deduplicação com TTL de 24 h e ACK correlacionado. O serviço `abp4-mqtt-worker` foi observado **LIVE no Render** em 11/11, com `mqtt conectado` no EMQX TLS 8883 e `/healthz` ok; a continuidade não foi medida ([`us-37.md`](evidencias/us-37.md)).
- **Mobile:** 12 telas do Figma nos dois temas, shell com abas Autorizações/Histórico/Perfil, login real, sessão persistida, scanner que envia o pedido e mostra o resultado, locais e administração. Executado em aparelho físico com APK debug; a publicação em loja não entrou.
- **Firmware:** display do QR, servo (simulado), LEDs, buzzer, ACK e recusa por prazo/dedup; NFC RC522 integrado (US-23) com evidência física inicial; **TLS com CA embutido validado no ESP32 real contra o EMQX** (conexão e negativos de CA/hostname). A abertura física da cancela não está implementada.
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
| US-28 | Telas "Minhas autorizações", detalhe e histórico no app | PR #69 |
| US-29 | Scanner envia o pedido de acesso e mostra liberado/negado; execução em aparelho | PR #55, [`us-29-aparelho.md`](evidencias/us-29-aparelho.md) |
| US-37 | Worker MQTT no Render; serviço LIVE observado em 11/11 | PR #26, [`us-37.md`](evidencias/us-37.md) |

## 5. Antecipações da S3

Trabalho com **Sprint alvo S3** que foi concluído dentro da janela da S2:

| Card | Entrega | Evidência |
|---|---|---|
| US-20 | Decisão de acesso QR real, evento auditado e geofence de 100 m | [evidência](evidencias/us-20.md), PR #42 |
| US-32 | E2E simulado no CI (PostgreSQL e broker temporários) | PR #32, [guia de desenvolvimento](../guides/desenvolvimento.md) |
| DT-23 | Teto de 100 m na política e CHECK de 1–100 m no banco, implantados | [evidência](evidencias/dt-23.md) |
| DT-24 | Actions por SHA e Dependabot semanal, ativos na `main` | [evidência](evidencias/dt-24.md) |
| US-30 | Administração de autorizações no app (criar, consultar, cancelar) | PR #69 |
| US-31 | Usuários e histórico de acessos no app | PR #69 |
| US-39 | Locais e cadastro de novo local (raio 1–100 m), API e tela | cadastro conferido no PostgreSQL, [`us-29-aparelho.md`](evidencias/us-29-aparelho.md) |

Além dessas, **22 das 24 dívidas técnicas** estão concluídas, incluindo TLS no firmware (DT-06), CORS (DT-08), APK no CI (DT-10), migrations no CD (DT-09), retenção de comandos (DT-18), prazos da deduplicação (DT-16) e janela do relay (DT-21). Ficaram abertas apenas **DT-12** e **DT-22**, ambas dependentes de bancada.

## 6. Qualidade e reprodução da demo

### Preparação

Usar a `main` de referência, dependências instaladas e os ambientes do [guia local](../guides/como-rodar.md), do [README mobile](../../mobile/README.md) e do [README firmware](../../firmware/README.md). Para o QR real, é preciso um terminal com credencial válida e um usuário com autorização vigente na seed de demonstração.

### Roteiro

1. **API publicada:** abrir `/health` (`database: ok`, versão `a0625d7`) e `/docs`; mostrar que o contrato e a implementação são o mesmo artefato gerado.
2. **Login e autorizações:** autenticar com a conta demo, criar uma autorização com janela e usos e consultar `GET /me/authorizations`. Mostrar que um usuário sem autorização recebe lista vazia, não erro.
3. **QR real:** gerar o QR assinado do terminal (US-19) e chamar `POST /api/v1/access-events/qr` com posição dentro e fora de 100 m. Mostrar `GRANTED` com evento e comando, e `DENIED` com `OUT_OF_RANGE` fora do raio. Repetir com o mesmo `requestId` e mostrar que a autorização **não** é consumida duas vezes.
4. **Terminal:** no Wokwi, mostrar o display recebendo o QR, o comando `open`, o servo e o ACK `executed`. O worker só publica QR para terminal considerado `online`, e o firmware atual **não envia heartbeat** (US-24); a demo precisa publicar status sintético (ou usar o simulador) e **identificar isso como simulação**. No hardware, mostrar a evidência de TLS com o EMQX e a leitura NFC da US-23; **não** prometer movimento de cancela nesta demo.
5. **App:** mostrar as 12 telas nos dois temas — login, sessão, minhas autorizações, detalhe, scanner lendo QR, resultado liberado/negado, perfil, locais com cadastro e administração (US-30/31). A execução em aparelho está registrada em [`us-29-aparelho.md`](evidencias/us-29-aparelho.md); deixar claro que a abertura física não foi demonstrada.
6. **Qualidade e operação:** abrir a aba Actions e mostrar os 6 checks obrigatórios, CodeQL e o Dependabot; mostrar a migration da DT-23 aplicada no Neon e a constraint ativa. No Render, mostrar o worker LIVE, o log `mqtt conectado` e o `/healthz` ([`us-37.md`](evidencias/us-37.md)).

**São provas separadas:** a API demonstra decisão e persistência; o Wokwi demonstra transporte e atuação simulada; o hardware comprova TLS e NFC; o app demonstra o fluxo de telas e o pedido. Nenhuma delas, isolada, prova o fluxo completo em campo nem a abertura física.

## 7. O que não entrou e por quê

**Encerrar a sprint não significa todos os itens do escopo físico.** O carry-over de app foi resolvido em 11/11 (US-28/29/30/31/39); o que segue fora é:

- **US-22 (demonstração visual do QR):** código presente e usado pelo worker, mas a demonstração visual atual no display do terminal não foi registrada.
- **Servo/cancela física:** o servo existe no firmware e é acionado em simulação; a abertura física da cancela **não está implementada**. O NFC (US-23) tem evidência física com servo desabilitado.
- **US-24 (heartbeat):** o firmware não publica status; a demo de QR no terminal precisa de status sintético identificado como simulação.
- **US-25 (resiliência offline):** o ACK tem uma tentativa, sem persistência offline.
- **APK de release em loja:** a execução em aparelho usou APK debug; não há AAB/keystore de release.
- **US-33 (revisão de segurança), US-35 (diagramas) e US-36 (relatório ABNT/apresentação)** seguem para a janela final.

**DT-12** (câmera real + APK em aparelho) teve execução manual em 11/11, mas o fechamento do card no board não foi reconferido nesta atualização. **DT-22** (corrente e 24 h de continuidade) segue bloqueada por bancada, com decisão e orçamento documentados, mas nenhuma corrente medida.

## 8. Dívida técnica e prioridades da S3

| Situação | Cards |
|---|---|
| Concluídas na S2 | DT-01 a DT-11, DT-13 a DT-21, DT-23, DT-24 |
| Concluídas em 11/11 | US-28, US-29, US-30, US-31 e US-39 |
| Bloqueadas por hardware | **DT-22** (corrente e 24 h de continuidade); **DT-12** teve câmera/APK debug observados em aparelho, mas o fechamento no board não foi reconferido |
| Prioridade da S3 | Fechar a bancada da US-34 (servo/cancela, DT-22, US-24 e US-25), registrar a demo visual do QR (US-22) e concluir US-33/US-35/US-36 |

## 9. Riscos

| Risco | Tratamento |
|---|---|
| Confundir app completo com fluxo físico | O app tem as 12 telas e envia o pedido, mas servo/cancela e o fluxo com terminal real não foram demonstrados; a demo separa as provas |
| `/health` verde mascarar integração incompleta | O smoke test cobre só API e banco; Render, app e hardware têm evidências próprias |
| Worker observado uma vez não provar continuidade | A observação de 11/11 cobre serviço LIVE, log e `/healthz`; uptime, reconexão e cota não foram medidos ([`us-37.md`](evidencias/us-37.md)) |
| Hardware atrasar servo, GPS e energia | NFC e câmera avançaram; concentrar a bancada na US-34 para servo/cancela, US-24, DT-22; não declarar medições não feitas |
| Migrations em produção | CD aplica migration antes do deploy; pré-check da DT-23 feito e registrado |
| Dependabot abrir PRs e alguém mergear sem review | Atualização é PR normal, com CI e revisão; sem auto-merge |
| Fechamento antecipado virar promessa de 100% | Este documento mantém o carry-over explícito e separa o que foi observado do que é código |

## 10. Próxima sprint

A **S3 ocorre de 12/11 a 25/11/2026**, com Review em 25/11 às 19h30. O foco é fechar o que falta do controle de acesso: heartbeat/status (US-24), resiliência offline (US-25), bancada e abertura física (US-34, DT-22), demonstração visual do QR (US-22), revisão de segurança (US-33), diagramas (US-35) e demo web (US-38). O relatório ABNT e a apresentação (US-36) ficam para a janela de entrega final. US-23, US-28, US-29, US-30, US-31 e US-39 já foram entregues.

**Dependência crítica:** US-24/25/34 e DT-22 dependem de bancada e de servo/cancela. Sem isso, a S3 fecha o software, mas não consegue declarar o aceite físico.

## 11. Rastreabilidade

- [Product backlog e critérios de aceite](../scrum/product-backlog.md).
- [Fechamento da Sprint 2](../scrum/sprints/sprint-2.md) · [roteiro da Review 2](../scrum/sprints/sprint-2-review.md) · [retrospectiva](../scrum/sprints/sprint-2-retro.md).
- [Definition of Done](../scrum/definition-of-done.md).
- [Matriz de requisitos](matriz-requisitos.md) e [índice de evidências](README.md).
- Evidências por card em [`evidencias/`](evidencias/); destaques: [US-20](evidencias/us-20.md), [US-29](evidencias/us-29.md), [US-29 em aparelho](evidencias/us-29-aparelho.md), [US-37](evidencias/us-37.md), [DT-01/02/03](evidencias/dt-01-02-03.md), [DT-06](evidencias/dt-06.md), [DT-08](evidencias/dt-08.md), [DT-23](evidencias/dt-23.md) e [DT-24](evidencias/dt-24.md).
- Rastreio: card `US-XX`/`DT-XX` → branch → linha `Card:` do PR → checks e merge. [PRs do projeto](https://github.com/ErrorSquad-ABP/ABP4-Sistema-Controle-Acesso/pulls?q=is%3Apr+is%3Amerged).

> **Nota de conferência:** no commit `1afd624` estão **28 PRs mergeados** desde a S1 (#26 a #65), com backend 458/458 (53 arquivos, PostgreSQL + seed) e mobile 93/93 na `main`, coletados em 10/11. A atualização de **11/11** usa backend **433 aprovados + 40 pulados**, Flutter **640**, `main` em `a0625d7` e o app no PR #69; os números medem execuções diferentes e não devem ser somados.
