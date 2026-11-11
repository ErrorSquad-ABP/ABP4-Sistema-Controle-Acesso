# Product Backlog — ErrorSquad ABP 4DSM

Este é o backlog oficial do **Sistema Integrado de Controle de Acesso** (QR Code + NFC + IoT): **39 user stories**, incluindo a US-39 descoberta após o plano original de 38. As 13 stories da **Sprint 1** estão detalhadas abaixo (narrativa + critérios de aceite); as demais são refinadas/estimadas sprint a sprint. As tabelas de sprint alvo preservam o planejamento original; o estado observado está na seção final, sem replanejamento retroativo.

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

- **Estimativa**: a S1 foi executada sem estimativa registrada; o acompanhamento foi por aceite e demonstração. A estimativa colaborativa volta na Planning 2, antes do compromisso. Nenhuma pontuação retroativa.
- **Prioridade**: definida pelo **PO**, não pela ordem em que as stories aparecem.
- **Dono**: a distribuição final da S1 está em [`sprints/sprint-1.md`](sprints/sprint-1.md); a partir da S2, cada um puxa o seu card na Planning.
- **Formato do card no Trello**: título `US-XX · Título`; descrição com a narrativa ("Como… quero… para…"), critérios de aceite em **checklist**, pontos e épico `(E1…E6)` no sufixo do título. Modelo completo na US-04.
- **Rastreio**: `US-XX` no card → título da branch → linha `Card: US-XX` do PR → execução.
- **Entrega final** = janela após a Review 3 (26/11 → data oficial da apresentação). O projeto tem **três sprints** (S1–S3); a entrega final não é uma quarta sprint.
- **Cortes de segurança** da Sprint 1: o corte chegou a ser aplicado em 21/10, mas US-08 e US-10 foram concluídas no mesmo dia. **Nenhum carry-over** para a S2.

---

## Sprint 1 — 13 stories detalhadas

**Goal**: fundação no ar + esqueleto conversando ponta-a-ponta, simulado (15/10 → 21/10, Review em 21/10).

Os critérios abaixo preservam o texto de planejamento; os checkboxes não foram remarcados retroativamente como resultado desta auditoria. Status declarado e ressalvas de comprovação estão na seção de estado atual e na [conferência por card](../entrega/auditoria-estado-atual.md).

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
- [ ] Workflow `ci-mobile.yml` verde em PR (analyze + test; build do APK e instalação em emulador desde a DT-10)
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

- [ ] `docs/architecture/contratos-mqtt.md` com a matriz QR, acesso (NFC/QR), heartbeat/LWT, comando e ACK (QoS, payloads, `messageId`/`terminalId`/`commandId`, expiração)
- [ ] Cliente mqtt.js + consumidor local (`npm run mqtt:consumer`) conectando no broker dev
- [ ] `npm run sim:terminal` publica a tentativa, o consumidor loga e o simulador responde ACK correlacionado
- [ ] Teste unitário do parser de payloads (inclui comando expirado)

**Card-exemplo de formato (Trello)** — modelo para todas as stories:

```text
Título:  US-04 · MQTT v1 + simulador (E5)

Descrição:
  Como dev do terminal IoT, quero o contrato MQTT dos tópicos do projeto
  documentado e um simulador de terminal publicando eventos, para
  desenvolver e testar o fluxo de acesso ponta-a-ponta sem depender do
  hardware físico.

Checklist (Critérios de aceite):
  [ ] docs/architecture/contratos-mqtt.md (QR, acesso NFC/QR, heartbeat/LWT,
      comando, ACK; QoS, ids e expiração)
  [ ] Cliente mqtt.js + consumidor local (npm run mqtt:consumer) no broker dev
  [ ] npm run sim:terminal publica tentativa; consumidor loga; ACK correlacionado
  [ ] Teste unitário do parser (inclui comando expirado)

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
- [ ] Contrato REST do pedido de acesso QR (`qrToken`, `terminalId`, posição e identidade autenticada), sem endpoints de NFC/heartbeat/ACK
- [ ] Rotas stub validadas com Zod (respondendo 501)
- [ ] Contrato congelado para o mobile

### US-07 · Esqueleto firmware

- **Épico**: E3 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev de firmware, quero o projeto PlatformIO com os módulos separados por responsabilidade e a simulação no Wokwi conectada ao Mosquitto do compose, para evoluir o terminal sem depender de hardware em mãos.

**Critérios de aceite**:

- [ ] Projeto PlatformIO com os módulos do terminal
- [ ] `config.example.h` (WiFi/broker/tópicos) sem segredos
- [ ] Simulação Wokwi conectando no Mosquitto do `docker-compose.dev.yml`
- [ ] Remover o skip do `ci-firmware` quando o `platformio.ini` entrar

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
- [ ] Estados de loading/erro
- [ ] Feedback de erro/sucesso sobre `successSoft`/`errorSoft`/`warningSoft` (contraste AA nos dois temas)
- [ ] Textos do Material em pt-BR (`flutter_localizations` + `supportedLocales`)

### US-11 · Documentos Scrum

- **Épico**: E6 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como time, quero os documentos Scrum dentro do repo (processo, product backlog, DoD, sprints e templates), para ter um processo rastreável e consistente com a spec desde a fundação do projeto.

**Critérios de aceite**:

- [ ] `docs/scrum/` completo: processo, product backlog com as 38 stories, DoD, sprints 1–3 e templates de review/retro
- [ ] Conteúdo consistente com a spec aprovada

### US-12 · Design no Figma (fase 1)

- **Épico**: E4/E6 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como dev, quero o design system e o fluxo do usuário desenhados no Figma, para implementar as telas mobile com tipografia, cores e componentes já definidos, sem decidir visual na hora do código.

**Critérios de aceite**:

- [ ] Design system (styles, tipografia Figtree, componentes base)
- [ ] Fluxo do usuário: login, autorizações, scanner, resultado e estados

### US-13 · CD + deploy inicial

- **Épico**: E1 · **Sprint**: 1 · **Pontos**: — (Planning 1)

**Narrativa**: Como time, quero o deploy automático do backend após merge na `main`, para validar a entrega em ambiente real (Vercel + Neon) já na Sprint 1, com healthcheck público.

**Critérios de aceite**:

- [ ] Workflow `cd-backend.yml` disparando deploy após merge na `main`
- [ ] Backend do esqueleto no ar no Vercel com healthcheck público
- [ ] Neon provisionado
- [ ] Secrets configurados

---

## Backlog futuro — US-14 a US-38 (25 stories)

Plano original, não uma lista de stories ainda abertas. Títulos, épico e sprint alvo conforme previsto; o refinamento detalha cada uma antes da sprint em que entra (narrativa + critérios de aceite + pontos). Várias já foram entregues ou antecipadas; ver estado abaixo.

| US | Título | Épico | Sprint alvo |
|---|---|---|---|
| US-14 | Auth JWT + perfis | E2 | S2 |
| US-15 | CRUD de usuários admin | E2 | S2 |
| US-16 | Criar autorização admin | E2 | S2 |
| US-17 | Consultar/cancelar autorização admin | E2 | S2 |
| US-18 | Minhas autorizações usuário | E2 | S2 |
| US-19 | Credencial QR rotativa + validação 25s | E2 | S2 |
| US-20 | Validação de acesso QR com geofence 100m | E2 | S3 |
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
| US-36 | Relatório ABNT e apresentação final | E6 | S3 (entrega final) |
| US-37 | Worker MQTT persistente no Render | E1 | S2 |
| US-38 | Demo web + identidade de distribuição na Vercel | E6 | S3 |

**US-37**: publica no Render o processo MQTT local da US-04, sem recriar a integração.
**US-38**: além do build web, troca os ícones padrão do Flutter (web e Android) por uma identidade única, com o nome público "Controle de Acesso".

### US-23 · NFC RC522 + feedback de decisão — refinamento S3

**Épico**: E3 · **Sprint alvo**: S3 · **Pontos**: a estimar pelo time.

**Status em 11/11/2026:** software antecipado na S2 e integrado no PR #67
(`a0625d7`), com correção `00ed519` que adia o ACK QoS 1 até `idle`.
O card permanece **Em review no Trello**, mesmo com flag `complete`;
host/build aprovados não substituem o aceite físico da revisão, que não teve
nova gravação em hardware. A evidência física anterior correlaciona
negativa/liberação/ACK com servo desligado: confirma feedback, não abertura.

**Narrativa**: Como usuário do terminal, quero aproximar minha tag NFC e receber
feedback visual e sonoro da decisão do backend, para saber se meu acesso foi
liberado ou negado sem que o terminal autorize uma tag por conta própria.

**Critérios de aceite** (negação/liberação reais registradas nas evidências;
checklist final depende da revisão e do aceite do time):

- [ ] RC522 lê UID de 4/7/10 bytes na pinagem da montagem de 07/11/2026.
- [ ] Tentativa v1 chega ao backend via MQTT QoS 1, sem retain, com UUID e UTC
      confiável; não há publicação offline com timestamp inventado.
- [ ] Mesma apresentação não gera avalanche; remoção por 500 ms rearma a tag.
- [ ] Credencial autorizada recebe feedback verde/agudo e desconhecida/revogada
      recebe vermelho/grave, somente após comando válido do backend.
- [ ] Falta de leitor/rede/hora não concede acesso; comandos duplicados ou
      vencidos não repetem atuação.
- [ ] Builds dos perfis físico e TFT legado e testes automatizados passam.
- [ ] Execução em hardware registrada no [roteiro US-23](../entrega/evidencias/us-23-nfc-rc522.md),
      sem confundir build/simulação com prova física. Buzzer e servo só são
      habilitados depois de confirmar compatibilidade e alimentação.

O perfil físico padrão usa OLED/LCD para status NFC. A variante
`TERMINAL_DISPLAY_OLED=1`, integrada pela US-29, mantém QR compacto no OLED;
o TFT permanece no perfil legado do Wokwi. As implementações são exclusivas.

**Distribuição original por épico** (cada story conta **uma vez**, pelo épico primário): E1 com 4 (3 na Sprint 1 + US-37) · E2 com 11 · E3 com 7 · E4 com 7 · E5 com 4 · E6 com 5 **(US-12 = E4/E6 compartilhada; contada em E6)** — **38 stories no plano inicial**, sendo 13 detalhadas na Sprint 1 e 25 previstas para depois. US-39 foi acrescentada posteriormente (seção de estado atual).

## Índice

- [`README.md`](README.md) — como o time aplica o Scrum.
- [`definition-of-done.md`](definition-of-done.md) — o que significa "pronto" para um card.
- `sprints/` e `templates/` completam a pasta (US-11).

## Estado observado em 02/11/2026 · fechamento da S2 atualizado em 11/11/2026

Código auditado em 02/11: `66fe44a`; API pública observada em `6b6aa26`, com banco ok (uma primeira consulta retornou 503). No **fechamento atualizado da S2** (11/11, commit `a0625d7`), a consulta completa do Trello registra **63 cards não arquivados**, sendo **49 em listas concluídas (27 US + 22 DT) + 1 em review (US-23)**, 1 em andamento, 10 na Sprint 3 e 2 bloqueados. Há 50 flags `complete` porque a US-23 também tem essa flag, mas seu card continua em review; não somar isso como 50 concluídos. A S2 tem **12/13 histórias concluídas no quadro**, restando US-28. Contagem não certifica todos os aceites: permanece a ressalva da US-22 (demonstração visual física). A US-37 passou a ter serviço observado no Render em 11/11 ([evidência](../entrega/evidencias/us-37.md)). O [review da S2](../entrega/review-2.md) registra o estado atual; a [auditoria por card](../entrega/auditoria-estado-atual.md) é histórica.

**Entregas integradas:** US-14/21/22/37 (#26), US-19 (#27, validade de 25 s alinhada em #64), US-15/18 (#33), US-16/17 (#36), US-27 (#43), US-26 herdada da US-08 ([evidência](../entrega/evidencias/us-26-mqtt-servo.md)), US-20 (#42), US-32 (E2E antecipado, #32) e **US-29 (#55, integrada em 10/11)**. Em 11/11 foram integrados #68 (Supertest, `4152809`) e #67 (**US-23 NFC RC522**, `a0625d7`, com correção `00ed519` do ACK QoS 1 adiado até `idle`), com 6 checks verdes e nenhum PR aberto na consulta. US-21 foi fechada pela fatia de consulta; decisões QR/NFC e o leitor RC522 agora têm software integrado. **US-23 continua em review**, sem nova gravação física da revisão; a evidência anterior tem servo desligado e ACK só de feedback. US-37 tem implementação e serviço observado no Render em 11/11 (`mqtt conectado`, `/healthz` ok), faltando o ciclo com terminal físico; US-22 tem código de renderização, não demonstração visual física atual comprovada. A descrição da US-14 foi alinhada em 08/11: sem refresh/logout no servidor, logout local no app.

**Listas abertas no Trello (11/11):** Sprint 3 = US-24/28/30/31/33/34/35/36/38/39; Em review = US-23; Em andamento = US-25; Bloqueado = DT-12/DT-22; Product Backlog e Sprint 2 vazios. **US-28 é carry-over para a S3**. A **US-29 está concluída no quadro e integrada**: login/sessão/Home/scanner enviam o pedido e exibem `GRANTED`/`DENIED`; ainda não há lista de autorizações nem admin no app (US-28/30/31). Em 11/11 o fluxo foi executado no aparelho com câmera e GPS reais (6,8 m liberado, 1.207,9 m negado) — ver [evidência no aparelho](../entrega/evidencias/us-29-aparelho.md). Restam build release e execução contra a API de produção (US-34/DT-12). As [capturas da review](../entrega/apresentacao-sprint2/README.md) distinguem app/API/worker/banco reais de status `online` e terminal/ACKs sintéticos. Heartbeat/GPS do terminal (US-24) e offline (US-25) seguem pendentes; build web local não fecha a publicação US-38.

**Qualidade e operação em 11/11:** CI backend da `main` com PostgreSQL/seed: **460/460** em 53 arquivos; suíte local padrão: **420 aprovados e 40 condicionais a banco pulados**; E2E **31/31**. Mobile: analyze limpo, **215/215** e build web aprovado. Firmware: suíte host aprovada, incluindo 8 cenários de timing (3 fases + PUBACK, TLS 0/1), e builds físico/Wokwi/TLS/OLED aprovados. API pública respondeu `version: a0625d7`, `database: ok`; CD backend, CI backend, firmware e CodeQL aprovados, com [execuções vinculadas no review](../entrega/review-2.md#6-qualidade-e-reprodução-da-demo). **Sem nova confirmação do worker no Render**, sem ESP32 conectado ou atuação de servo nesta demo.

> **Histórico do corte intermediário de 10/11 (`1afd624`):** o registro anterior indicava 11/13 histórias da S2, US-28/29 como carry-over, 48/63 cards (26 US + 22 DT), 28 PRs e testes backend 458/mobile 93. Preservado como histórico, não como estado atual: PR #55 (US-29) e PR #64 (QR de 25 s) já foram integrados em 10/11.

**Dívidas declaradas concluídas:** DT-01 a DT-11, DT-13 a DT-21, DT-23 e DT-24. A **DT-11** ficou fechada pela **DT-24**, que integrou a pinagem por SHA e o Dependabot (#56). O teto de 100 m da **DT-23** também foi integrado e a migration aplicada em produção no mesmo dia. A **DT-16** foi mergeada no #51; os limites (pooler do Neon e callback dentro da transação de acesso) estão documentados na evidência. Seguem abertas **DT-12** (câmera real + APK) e **DT-22** (corrente e continuidade), ambas dependentes de bancada.

### US-39 · Cadastro de locais de acesso (RF02) — descoberta em 29/10

- **Épico:** E2/E4 (proposta de classificação, a confirmar) · **Sprint alvo:** a definir (candidata S3, não comprometida) · **Status Trello:** Product Backlog · [Card](https://trello.com/c/Lg7ehTp4).
- CRUD admin de locais, endereço/complemento separados de ponto geográfico confirmado, vínculo terminal→local e desativação; sem ampliar o limite QR de 100 m. O card detalha captura/validação do ponto de instalação, cenários sem posição e distinção entre coordenadas reais/simuladas.
- `AccessLocation`/seed/mapeamento existem, mas **não há endpoint nem tela funcional** de cadastro; os PNGs claro/escuro são design, não implementação.
- A distribuição histórica acima soma as 38 stories originais; a US-39 é adicional e sua classificação definitiva depende de refinamento.

**DT-22 (RNF07):** decisão, estimativas e procedimento de medição já estão em [`../entrega/evidencias/dt-22.md`](../entrega/evidencias/dt-22.md); consumo e continuidade não foram medidos. A descrição no Trello foi sincronizada em 08/11: estratégia documentada, medição de corrente/continuidade pendente (US-34).

Detalhe da sprint em [`sprints/sprint-2.md`](sprints/sprint-2.md). A API na Vercel não comprova a operação do worker no Render nem o fluxo físico completo.
