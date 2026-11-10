# Sprint 2 — Fluxo QR real (22/10 → 11/11)

- **Planning 2**: início da sprint · **Review 2**: 11/11 19h30 · **Retro**: logo após a review (30 min)
- **Foco macro**: fluxo QR real ponta-a-ponta + admin + deploy + design admin/terminal
- **Fechamento do trabalho: 10/11/2026** · commit de referência `1afd624` · **11/13 histórias da S2** concluídas, com US-20/US-32/DT-23/DT-24 antecipadas da S3

## Escopo previsto

Stories do backlog com **Sprint alvo S2** no [`product-backlog.md`](../product-backlog.md). O refinamento fatiar e detalha cada uma antes de entrar na sprint (narrativa + critérios de aceite + pontos); o escopo final é fechado na Planning 2.

### Carregados da Sprint 1

**Nenhum.** US-08 e US-10 foram concluídas em 21/10 (PRs #19 e #20) e não há carry-over para a S2.

| US | Título | Épico | Sprint alvo |
|---|---|---|---|
| US-14 | Auth JWT + perfis | E2 | S2 |
| US-15 | CRUD de usuários admin | E2 | S2 |
| US-16 | Criar autorização admin | E2 | S2 |
| US-17 | Consultar/cancelar autorização admin | E2 | S2 |
| US-18 | Minhas autorizações usuário | E2 | S2 |
| US-19 | Credencial QR rotativa + validação 10s | E2 | S2 |
| US-21 | Eventos de acesso + histórico com filtros | E2 | S2/S3 |
| US-22 | Display: render do QR + status | E3 | S2 |
| US-26 | Comando de abertura do servo via MQTT | E3 | S2 |
| US-27 | Login real + sessão | E4 | S2 |
| US-28 | Minhas autorizações no app | E4 | S2 |
| US-29 | Scanner QR + resultado no app | E4 | S2 |
| US-37 | Worker MQTT persistente no Render | E1 | S2 |

**US-21 (S2/S3)** entrou fatiada: a consulta foi entregue no PR #26; hoje a decisão também grava QR e NFC simulado. O leitor/publicação NFC do ESP32 continua pendente na US-23.

**US-20 (antecipada na S2)**: a decisão de acesso QR estava prevista para a S3, mas o endpoint deixou de ser stub junto com o fluxo QR real (DT-01/02/03) e a story fechou no PR #42, com a evidência de geofence de 100 m em [`us-20.md`](../../entrega/evidencias/us-20.md). `POST /access-events/qr` decide e registra o evento; não responde mais `501`.

Resumo por épico: **E2** (identidade, autorizações, QR e eventos) concentra o fluxo real · **E3** (display do QR e abertura do servo) fecha o ciclo no terminal · **E4** (login, minhas autorizações e scanner) entrega o app usando o contrato da S1.

## Sprint Goal

A definir na Planning 2. O goal nasce do foco macro acima (fluxo QR real ponta-a-ponta com admin e deploy no ar) e é registrado aqui na planning.

## Backlog detalhado da sprint

Cards puxados na Planning 2. Pontos ficam "—" enquanto a estimativa colaborativa não for registrada (mesma regra da S1: nada de pontuação retroativa).

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| US-14 | Auth JWT + perfis | João (card era do Felipe; alinhar) | — | Concluído (#26) |
| US-15 | CRUD de usuários admin | — | — | Concluído (#33) |
| US-16 | Criar autorização admin | Caio | — | Concluído (#36) |
| US-17 | Consultar/cancelar autorização admin | Caio | — | Concluído (#36) |
| US-18 | Minhas autorizações usuário | — | — | Concluído (#33) |
| US-19 | Credencial QR rotativa + validação 10s | Caio | — | Concluído (#27) |
| US-21 | Eventos de acesso + histórico com filtros | João | — | Concluído na fatia de consulta (#26); integração com leitor NFC pendente em US-23 |
| US-22 | Display: render do QR + status | João | — | Concluído no Trello (#26); código presente, demonstração visual pendente |
| US-26 | Comando de abertura do servo via MQTT | João | — | Concluído (herdado da US-08) |
| US-27 | Login real + sessão | Felipe | — | Concluído (#43) |
| US-28 | Minhas autorizações no app | — | — | **Não entregue — S3** (API pronta desde a US-18) |
| US-29 | Scanner QR + resultado no app | Leo | — | **Em review — S3** (PR #55 aberto, não integrado; falta câmera/GPS reais; evidência [`us-29.md`](../../entrega/evidencias/us-29.md)) |
| US-37 | Worker MQTT persistente no Render | João | — | Concluído no Trello (#26); implementação presente, deploy não comprovado |

**US-20 (fora da tabela porque não foi puxada na Planning 2)**: antecipada e declarada concluída em 28/10 pelo PR #42 — `/access-events/qr` decide e registra o evento. O teto de 100 m passou a ser imposto pela DT-23, mergeada e implantada em 10/11 com CHECK de 1–100 m no banco.

**Fechamento em 10/11/2026 — sprint encerrada:** das 13 histórias da tabela, **11 estão concluídas**; **US-28** (não iniciada) e **US-29** (PR #55 aberto em review, sem validação de câmera/GPS) passam para a S3. O board tem **48 cards concluídos de 63** (26 US + 22 DT), 1 em review, 2 em andamento, 10 na Sprint 3 (Product Backlog vazio) e 2 bloqueados (DT-12 e DT-22). Não contar US-22/37 como aceites integralmente comprovados: faltam demonstração visual e deploy no Render. A sprint também absorveu **22 das 24 dívidas técnicas** e antecipou **US-20, US-32, DT-23 e DT-24**.

**Board em 10/11:** a lista Sprint 2 está vazia (sprint encerrada); **US-29** está em Em review; **US-23** e **US-25** em Em andamento; **US-24, US-28, US-30, US-31, US-33, US-34, US-35, US-36, US-38 e US-39** na **Sprint 3**; **DT-12** e **DT-22** em Bloqueado. O Product Backlog está vazio. Isso descreve o quadro, sem inventar transferência de escopo: US-28/29 foram explicitamente declaradas carry-over para a S3. Conferência em [`../../entrega/review-2.md`](../../entrega/review-2.md).

**Corte da US-21 nesta sprint**: entrou só a fatia de **consulta** (`GET /me/access-events` e `GET /access-events`), entregue no PR #26. DT-03/04 e US-20 acrescentaram mapeamento, representação sem local e decisão/gravação. O backend já cobre NFC em simulação; a integração com o leitor real segue na US-23, hoje em Em andamento.

**US-26**: os critérios já eram cobertos pelo firmware entregue na US-08 (comando v1 com prazo, dedup, ACK e servo); o card fecha com a evidência de `test_mqtt_command` e da simulação Wokwi.

## Burndown simples

A S2 não teve estimativa por pontos registrada; o acompanhamento foi por aceite, status no board e evidência. Totais do fechamento em [`../../entrega/review-2.md`](../../entrega/review-2.md).

| Dia | Pontos restantes |
|---|---|
| 22/10 → 11/11 | — (sem estimativa por pontos) |

## Fechamento

| Indicador | Resultado em 10/11 |
|---|---|
| Histórias da S2 | 11/13 · US-28 e US-29 para a S3 |
| Antecipações da S3 | US-20, US-32, DT-23, DT-24 |
| Cards no board | 48/63 concluídos (26 US + 22 DT) |
| PRs mergeados | 28 (#26–#65) |
| Backend | 458 testes em 53 arquivos (PostgreSQL + seed) |
| Mobile (`main`) | 93 testes (a US-29 leva a 215 no PR #55) |
| Firmware | 12 executáveis host + 6 cenários de timing; builds padrão/TLS |
| Produção | `/health` `2dd532b`, `database: ok`; CHECK de 1–100 m aplicada |

Documento da cerimônia: [`sprint-2-review.md`](sprint-2-review.md) · retro: [`sprint-2-retro.md`](sprint-2-retro.md) · entrega: [`../../entrega/review-2.md`](../../entrega/review-2.md).
