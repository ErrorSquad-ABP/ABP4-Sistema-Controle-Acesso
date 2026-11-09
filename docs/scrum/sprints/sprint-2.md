# Sprint 2 — Fluxo QR real (22/10 → 11/11)

- **Planning 2**: início da sprint · **Review 2**: 11/11 19h30 · **Retro**: logo após a review (30 min)
- **Foco macro**: fluxo QR real ponta-a-ponta + admin + deploy + design admin/terminal

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
| US-28 | Minhas autorizações no app | — | — | Pendente |
| US-29 | Scanner QR + resultado no app | — | — | Pendente |
| US-37 | Worker MQTT persistente no Render | João | — | Concluído no Trello (#26); implementação presente, deploy não comprovado |

**US-20 (fora da tabela porque não foi puxada na Planning 2)**: antecipada e declarada concluída em 28/10 pelo PR #42 — `/access-events/qr` decide e registra o evento. A configuração testada usa 100 m; a política não impõe esse teto para raios maiores (ressalva da auditoria de 02/11).

**Snapshot em 02/11/2026, board reconferido em 08/11/2026 — sprint ainda em curso:** das 13 stories da tabela, 11 estão em Concluído no Trello, incluindo o corte de consulta da US-21; **US-28** e **US-29** continuam abertas. Não chamar de fechamento nem contar US-22/37 como aceites integralmente comprovados: faltam demonstração visual/deploy. US-14 tem corte de refresh/logout refletido na descrição desde 08/11. A auditoria também encontrou ausência de teto absoluto de 100 m na US-20, rastreada na DT-23.

Em 08/11, a lista **Sprint 2** do Trello tem **US-24**; **US-23, US-25, US-29, DT-06 e DT-08** estão em Em andamento; US-28 está no Product Backlog. US-20 e US-32 foram antecipadas do plano S3. Isso descreve o quadro, sem inventar nova Planning, compromisso ou transferência de US-28/29 para S3. O planejamento detalhado de donos/pontos acima não foi revalidado. Conferência em [`../../entrega/auditoria-estado-atual.md`](../../entrega/auditoria-estado-atual.md).

**Corte da US-21 nesta sprint**: entrou só a fatia de **consulta** (`GET /me/access-events` e `GET /access-events`), entregue no PR #26. DT-03/04 e US-20 acrescentaram mapeamento, representação sem local e decisão/gravação. O backend já cobre NFC em simulação; a integração com o leitor real segue na US-23, hoje em Em andamento.

**US-26**: os critérios já eram cobertos pelo firmware entregue na US-08 (comando v1 com prazo, dedup, ACK e servo); o card fecha com a evidência de `test_mqtt_command` e da simulação Wokwi.

## Burndown simples

Total definido na Planning 2; pontos restantes preenchidos durante a sprint.

| Dia | Pontos restantes |
|---|---|
| 22/10 → 11/11 | — (preencher por dia na sprint) |
