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

**US-21 (S2/S3)** entra fatiada: a fatia da S2 fecha na Review 2; o restante segue na Sprint 3.

**US-20 (ponto de atenção para a Planning 2)**: o fluxo QR ponta-a-ponta depende da decisão de acesso da US-20, cujo endpoint ainda responde 501 e está previsto para a S3. Sem uma fatia dela, a S2 entrega credencial e leitura, mas não a decisão. A Planning 2 deve incluir a fatia ou reduzir explicitamente a promessa do foco.

Resumo por épico: **E2** (identidade, autorizações, QR e eventos) concentra o fluxo real · **E3** (display do QR e abertura do servo) fecha o ciclo no terminal · **E4** (login, minhas autorizações e scanner) entrega o app usando o contrato da S1.

## Sprint Goal

A definir na Planning 2. O goal nasce do foco macro acima (fluxo QR real ponta-a-ponta com admin e deploy no ar) e é registrado aqui na planning.

## Backlog detalhado da sprint

Cards puxados na Planning 2. Pontos ficam "—" enquanto a estimativa colaborativa não for registrada (mesma regra da S1: nada de pontuação retroativa).

| US | Título | Dono | Pontos | Status |
|---|---|---|---|---|
| US-14 | Auth JWT + perfis | João (card era do Felipe; alinhar) | — | Em review |
| US-15 | CRUD de usuários admin | — | — | Pendente |
| US-16 | Criar autorização admin | Caio | — | Pendente |
| US-17 | Consultar/cancelar autorização admin | Caio | — | Pendente |
| US-18 | Minhas autorizações usuário | — | — | Pendente |
| US-19 | Credencial QR rotativa + validação 10s | Caio | — | Pendente |
| US-21 | Eventos de acesso + histórico com filtros | João | — | Em review (fatia de consulta) |
| US-22 | Display: render do QR + status | João | — | Em review |
| US-26 | Comando de abertura do servo via MQTT | João | — | Concluído (herdado da US-08) |
| US-27 | Login real + sessão | Felipe | — | Pendente |
| US-28 | Minhas autorizações no app | — | — | Pendente |
| US-29 | Scanner QR + resultado no app | — | — | Pendente |
| US-37 | Worker MQTT persistente no Render | João | — | Em review |

**Corte da US-21 nesta sprint**: entra só a fatia de **consulta** (`GET /me/access-events` e `GET /access-events`). A gravação de novas tentativas continua com US-20/US-23 porque depende do mapeamento terminal→local (DT-03) e da representação de evento sem local no contrato (DT-04). O restante volta na Sprint 3.

**US-26**: os critérios já eram cobertos pelo firmware entregue na US-08 (comando v1 com prazo, dedup, ACK e servo); o card fecha com a evidência de `test_mqtt_command` e da simulação Wokwi.

## Burndown simples

Total definido na Planning 2; pontos restantes preenchidos durante a sprint.

| Dia | Pontos restantes |
|---|---|
| 22/10 → 11/11 | — (preencher por dia na sprint) |
