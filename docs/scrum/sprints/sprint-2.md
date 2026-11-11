# Sprint 2 — Fluxo QR real (22/10 → 11/11)

- **Planning 2**: início da sprint · **Review 2**: 11/11 19h30 · **Retro**: logo após a review (30 min)
- **Foco macro**: fluxo QR real ponta-a-ponta + admin + deploy + design admin/terminal
- **Fechamento atualizado em 11/11/2026** · commit de referência `a0625d7` · **12/13 histórias da S2 concluídas no quadro**; US-28 pendente, com ressalvas de comprovação em US-22/37. US-20/US-32/DT-23/DT-24 antecipadas da S3, além do software da US-23 (card em review).

## Escopo previsto

Stories do backlog com **Sprint alvo S2** no [`product-backlog.md`](../product-backlog.md). O escopo previsto é preservado abaixo; não foram atribuídos pontos retroativamente.

### Carregados da Sprint 1

**Nenhum.** US-08 e US-10 foram concluídas em 21/10 (PRs #19 e #20) e não há carry-over para a S2.

| US | Título | Épico | Sprint alvo |
|---|---|---|---|
| US-14 | Auth JWT + perfis | E2 | S2 |
| US-15 | CRUD de usuários admin | E2 | S2 |
| US-16 | Criar autorização admin | E2 | S2 |
| US-17 | Consultar/cancelar autorização admin | E2 | S2 |
| US-18 | Minhas autorizações usuário | E2 | S2 |
| US-19 | Credencial QR rotativa + validação 25s | E2 | S2 |
| US-21 | Eventos de acesso + histórico com filtros | E2 | S2/S3 |
| US-22 | Display: render do QR + status | E3 | S2 |
| US-26 | Comando de abertura do servo via MQTT | E3 | S2 |
| US-27 | Login real + sessão | E4 | S2 |
| US-28 | Minhas autorizações no app | E4 | S2 |
| US-29 | Scanner QR + resultado no app | E4 | S2 |
| US-37 | Worker MQTT persistente no Render | E1 | S2 |

**US-21 (S2/S3)** entrou fatiada: a consulta foi entregue no PR #26; a decisão também grava QR/NFC. O leitor/publicação NFC do ESP32 foi integrado pela US-23 no PR #67 em 11/11; o card segue em review e a revisão não teve nova gravação em hardware.

**US-20 (antecipada na S2)**: a decisão de acesso QR estava prevista para a S3, mas o endpoint deixou de ser stub junto com o fluxo QR real (DT-01/02/03) e a story fechou no PR #42, com a evidência de geofence de 100 m em [`us-20.md`](../../entrega/evidencias/us-20.md). `POST /access-events/qr` decide e registra o evento; não responde mais `501`.

Resumo por épico: **E2** (identidade, autorizações, QR e eventos) concentra o fluxo real · **E3** (display do QR e abertura do servo) fecha o ciclo no terminal · **E4** (login, minhas autorizações e scanner) entrega o app usando o contrato da S1.

## Sprint Goal

Foco usado nesta review: fluxo QR real ponta-a-ponta, admin na API e deploy seguro. O goal formal da Planning 2 não foi registrado neste documento; não é reconstruído retroativamente. O incremento e seus limites estão no fechamento abaixo.

## Backlog detalhado da sprint

Cards puxados na Planning 2. Pontos ficam "—" enquanto a estimativa colaborativa não for registrada (mesma regra da S1: nada de pontuação retroativa).

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| US-14 | Auth JWT + perfis | João (card era do Felipe; alinhar) | — | Concluído (#26) |
| US-15 | CRUD de usuários admin | — | — | Concluído (#33) |
| US-16 | Criar autorização admin | Caio | — | Concluído (#36) |
| US-17 | Consultar/cancelar autorização admin | Caio | — | Concluído (#36) |
| US-18 | Minhas autorizações usuário | — | — | Concluído (#33) |
| US-19 | Credencial QR rotativa + validação 25s | Caio | — | Concluído (#27); validade alinhada em #64 |
| US-21 | Eventos de acesso + histórico com filtros | João | — | Concluído na fatia de consulta (#26); leitor NFC integrado pela US-23 (#67), card em review |
| US-22 | Display: render do QR + status | João | — | Concluído no Trello (#26); código presente, demonstração visual pendente |
| US-26 | Comando de abertura do servo via MQTT | João | — | Concluído (herdado da US-08) |
| US-27 | Login real + sessão | Felipe | — | Concluído (#43) |
| US-28 | Minhas autorizações no app | — | — | **Não entregue — S3** (API pronta desde a US-18) |
| US-29 | Scanner QR + resultado no app | Leo | — | **Concluído no quadro e integrado** (#55, em 10/11); pedido QR e resultado reais, câmera/GPS físicos pendentes na US-34/DT-12; [evidência](../../entrega/evidencias/us-29.md) |
| US-37 | Worker MQTT persistente no Render | João | — | Concluído no Trello (#26); implementação presente, deploy não comprovado |

**US-20 (fora da tabela porque não foi puxada na Planning 2)**: antecipada e declarada concluída em 28/10 pelo PR #42 — `/access-events/qr` decide e registra o evento. O teto de 100 m passou a ser imposto pela DT-23, mergeada e implantada em 10/11 com CHECK de 1–100 m no banco.

**Fechamento atualizado em 11/11/2026:** das 13 histórias da tabela, **12 estão concluídas no quadro**; resta **US-28** (não iniciada), carry-over para a S3. A **US-29 já está integrada**, não é pendência de implementação; câmera/GPS físicos seguem na US-34/DT-12. Não contar US-22/37 como aceites integralmente comprovados: faltam demonstração visual física e deploy no Render. A sprint absorveu **22 das 24 dívidas técnicas**, antecipou **US-20, US-32, DT-23 e DT-24** e integrou o software da **US-23** (NFC), mantendo seu card em review.

**Board em 11/11 (consulta completa):** **63 cards**, com **49 em listas concluídas (27 US + 22 DT)**; **US-23 Em review**, **US-25 Em andamento**, **US-24/28/30/31/33/34/35/36/38/39 na Sprint 3** e **DT-12/DT-22 Bloqueados**. Product Backlog e Sprint 2 vazios. A flag `complete` aparece em 50 cards porque inclui a US-23, mas **não equivale a 50 em listas concluídas**. Nenhum card foi movido nesta atualização documental. Conferência em [`../../entrega/review-2.md`](../../entrega/review-2.md).

**Corte da US-21 nesta sprint**: entrou só a fatia de **consulta** (`GET /me/access-events` e `GET /access-events`), entregue no PR #26. DT-03/04 e US-20 acrescentaram mapeamento, representação sem local e decisão/gravação. A US-23 integrou o RC522 físico no PR #67 (`a0625d7`), com correção `00ed519` que adia o ACK QoS 1 até `idle`. Os testes de host/build passaram, sem nova gravação física da revisão. A [evidência física anterior](../../entrega/evidencias/us-23-nfc-rc522.md) correlaciona negativa/liberação/ACK com servo desligado: confirma feedback, não abertura.

**US-26**: os critérios já eram cobertos pelo firmware entregue na US-08 (comando v1 com prazo, dedup, ACK e servo); o card fecha com a evidência de `test_mqtt_command` e da simulação Wokwi.

## Burndown simples

A S2 não teve estimativa por pontos registrada; o acompanhamento foi por aceite, status no board e evidência. Totais do fechamento em [`../../entrega/review-2.md`](../../entrega/review-2.md).

| Dia | Pontos restantes |
|---|---|
| 22/10 → 11/11 | — (sem estimativa por pontos) |

## Fechamento

| Indicador | Resultado em 11/11 |
|---|---|
| Histórias da S2 | 12/13 no quadro · US-28 para a S3; ressalvas US-22/37 |
| Antecipações da S3 | US-20, US-32, DT-23, DT-24; software US-23 integrado, card em review |
| Cards no board | 49/63 em listas concluídas (27 US + 22 DT), mais 1 em review |
| Integrações de 11/11 | #68 Supertest (`4152809`) e #67 NFC (`a0625d7`); 6 checks verdes; nenhum PR aberto na consulta |
| Backend | CI: 460/460 em 53 arquivos (PostgreSQL + seed); local padrão: 420 aprovados/40 condicionais a banco pulados; E2E: 31/31 |
| Mobile | analyze limpo, 215/215 testes e build web aprovado; build local não é publicação US-38 |
| Firmware | Suíte host aprovada, incluindo 8 cenários de timing (3 fases + PUBACK, TLS 0/1); builds físico/Wokwi/TLS/OLED aprovados |
| Produção | `/health` `a0625d7`, `database: ok`; CD aprovado e CHECK de 1–100 m aplicada; worker MQTT `live` no Render com `mqtt conectado` |

**Demonstração sem hardware:** app Flutter real com login/sessão/Home/scanner e resultado `GRANTED`/`DENIED`, API/worker/decisor/banco reais locais; câmera Y4M, GPS, status `online` e terminal/ACKs sintéticos. QR dentro/fora de 100 m, replay idempotente e NFC autorizado/desconhecido foram exercitados. Não comprova câmera/GPS físicos, ESP32 conectado nem atuação de servo. US-24 (GPS/heartbeat) e US-25 (offline) seguem pendentes. [Capturas e execução sanitizada](../../entrega/apresentacao-sprint2/README.md) apoiam a review de 10–15 min.

> **Histórico do corte intermediário (10/11, `1afd624`):** o registro anterior indicava 11/13, US-28/29 como carry-over, 48/63 cards (26 US + 22 DT), 28 PRs e testes backend 458/mobile 93. Não é o estado atualizado de 11/11: a US-29 (#55) e o QR de 25 s (#64) já foram integrados em 10/11.

Documento da cerimônia: [`sprint-2-review.md`](sprint-2-review.md) · retro: [`sprint-2-retro.md`](sprint-2-retro.md) · entrega: [`../../entrega/review-2.md`](../../entrega/review-2.md).
