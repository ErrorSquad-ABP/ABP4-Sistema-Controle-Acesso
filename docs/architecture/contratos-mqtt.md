# Contrato MQTT v1

Contrato das mensagens entre o **Terminal de Acesso** (ESP32) e o **backend** (processo MQTT). A matriz de transporte e o porquê de cada canal estão em [`visao-geral.md`](visao-geral.md); aqui ficam tópicos, payloads, QoS, ids e expiração. Esta é a fonte da verdade: o parser do backend ([`payload-parser.ts`](../../backend/src/infrastructure/mqtt/payload-parser.ts)), o simulador e o firmware (US-07) seguem este documento.

O pedido de acesso por QR **não** passa por MQTT: o app o envia à API por HTTPS REST (US-06). O MQTT cobre o QR rotativo publicado ao terminal, a leitura NFC, o heartbeat, o comando e o ACK.

## Tópicos

`{id}` é o `terminalId` (ex.: `terminal-01`): 1 a 64 caracteres, só minúsculas, dígitos e hífen, começando por letra ou número (regra única em `backend/src/shared/terminal-id.ts`).

| Tópico | Sentido | QoS | Retain | Mensagem |
|---|---|---|---|---|
| `terminals/{id}/qr` | backend → terminal | 0 | não | QR rotativo |
| `terminals/{id}/access-events` | terminal → backend | 1 | não | tentativa de acesso (leitura NFC) |
| `terminals/{id}/status` | terminal → backend | 1 | **sim** | heartbeat e LWT |
| `terminals/{id}/commands` | backend → terminal | 1 | não | comando de abertura ou negação |
| `terminals/{id}/acks` | terminal → backend | 1 | não | ACK de execução |

- O QR usa QoS 0 porque renova a cada 10 s: perder um token é irrelevante, o próximo chega logo.
- O `status` é retido para que um consumidor que entra depois veja o último estado conhecido (online ou offline).
- Comandos nunca são retidos: um comando antigo entregue a um terminal que reconecta seria perigoso.
- O backend assina `terminals/+/access-events`, `terminals/+/status` e `terminals/+/acks`.

## Envelope comum

Todo payload é JSON UTF-8 com estes campos:

| Campo | Tipo | Descrição |
|---|---|---|
| `v` | inteiro | versão do contrato (`1`) |
| `messageId` | UUID | identifica a mensagem; o consumidor **deduplica** por ele |
| `terminalId` | string | deve coincidir com o `{id}` do tópico |
| `timestamp` | ISO 8601 UTC | instante em que o produtor gerou a mensagem |

Mensagem com `v` desconhecida, `terminalId` diferente do tópico ou campo faltando é **descartada** e logada, sem resposta.

## Mensagens

### QR rotativo — `terminals/{id}/qr`

```json
{
  "v": 1,
  "messageId": "3f0c2c7e-8a41-4a47-9b0e-6a8f5d2f1c10",
  "terminalId": "terminal-01",
  "timestamp": "2026-10-19T19:30:00.000Z",
  "token": "v1.terminal-01.1792438200.1792438210.assinatura-base64url",
  "expiresAt": "2026-10-19T19:30:10.000Z"
}
```

`token` é emitido pelo backend como `v1.<terminalId>.<iat>.<exp>.<assinatura>`, com `iat`/`exp` em segundos Unix e assinatura `base64url(HMAC-SHA-256)` sobre os quatro primeiros campos. O formato é compacto de propósito: o QR do terminal é versão 8 / ECC_LOW (152 bytes) e precisa caber até com `terminalId` de 64 caracteres. A chave vem de `QR_TOKEN_SECRET`, compartilhada pelos processos HTTP e MQTT; ela nunca segue na mensagem. `timestamp` é o instante `iat`, e `expiresAt` da mensagem é o mesmo instante de expiração assinado no token (`iat` + 10 s). O terminal só exibe o token. A validação criptográfica rejeita assinatura inválida, terminal divergente, timestamps incoerentes e token expirado; ela não concede acesso.

### Tentativa de acesso — `terminals/{id}/access-events`

```json
{
  "v": 1,
  "messageId": "9a6d1b52-3d0e-4d8e-a2b5-1c7f0e4a8b21",
  "terminalId": "terminal-01",
  "timestamp": "2026-10-19T19:30:03.120Z",
  "type": "nfc_read",
  "uid": "04A1B2C3"
}
```

`type` é `nfc_read` na v1; `uid` é hexadecimal maiúsculo (4 a 20 caracteres). O backend decide; o terminal só aguarda o comando.

O `timestamp` deve ter idade **menor que 30 s**, com tolerância de até **5 s no futuro**. O parser e o caso de uso rejeitam tentativas fora dessa janela (`stale`), sem decidir nem publicar comando. A fila não renova o prazo; o terminal precisa manter seu relógio UTC sincronizado.

### Heartbeat e LWT — `terminals/{id}/status`

```json
{
  "v": 1,
  "messageId": "0b8e5f43-7c1a-4b6e-8d92-3a4f9c6e7d10",
  "terminalId": "terminal-01",
  "timestamp": "2026-10-19T19:29:50.000Z",
  "state": "online",
  "firmware": "0.1.0"
}
```

- `state`: `online` ou `offline`. `firmware` é opcional.
- O terminal publica `online` ao conectar e a cada 30 s (heartbeat), sempre com retain.
- **LWT** (last will): ao conectar, o terminal registra no broker um `state: "offline"` no mesmo tópico, QoS 1 e retain. Se a conexão cair sem desconexão limpa, o broker publica esse payload. Por ser registrado antes da queda, o `timestamp` do LWT é o da conexão.

### Comando — `terminals/{id}/commands`

```json
{
  "v": 1,
  "messageId": "5d7c9a10-2b3e-4f61-a8d4-9e0b1c2d3f45",
  "terminalId": "terminal-01",
  "timestamp": "2026-10-19T19:30:03.400Z",
  "commandId": "c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c01",
  "expiresAt": "2026-10-19T19:30:13.400Z",
  "action": "open",
  "reason": "nfc_authorized"
}
```

- `action`: `open` (liberar) ou `deny` (negar, com feedback de erro no LED/buzzer).
- `commandId` correlaciona o comando ao ACK; `expiresAt` é o prazo de execução (padrão: `timestamp` + 10 s).
- **O terminal rejeita comando expirado** (`expiresAt` ≤ agora) e responde ACK `expired`, sem acionar o servo.
- O terminal **deduplica** por `commandId`: um comando repetido não abre a porta duas vezes (responde o ACK anterior).

### ACK — `terminals/{id}/acks`

```json
{
  "v": 1,
  "messageId": "e2a1b0c9-4d3f-4e5a-b6c7-8d9e0f1a2b3c",
  "terminalId": "terminal-01",
  "timestamp": "2026-10-19T19:30:04.050Z",
  "commandId": "c7e4f1a2-6b3d-4c58-9f10-2a8b5d7e9c01",
  "status": "executed"
}
```

- `status`: `executed` (comando cumprido), `rejected` (recusado, com `reason`) ou `expired` (chegou vencido).
- O ACK **não concede acesso**: só confirma que o terminal executou, recusou ou ignorou um comando. O backend correlaciona pelo `commandId`; ACK de comando desconhecido é logado e ignorado.

## Ids e idempotência

| Id | Gerado por | Uso |
|---|---|---|
| `messageId` | produtor da mensagem | dedup do consumidor (persistente para tentativas NFC em modo real) |
| `commandId` | backend | correlação comando ↔ ACK e dedup no terminal |
| `terminalId` | configuração do terminal | roteamento e conferência com o tópico |

QoS 1 pode entregar a mesma mensagem mais de uma vez; por isso a dedup por `messageId`/`commandId` é obrigatória dos dois lados.

No modo real, `ProcessedAccessMessage` registra tentativas concluídas sem limite FIFO de 1.000 IDs. Uma reserva transacional PostgreSQL serializa o mesmo ID entre instâncias; qualquer falha faz rollback, e a queda da conexão libera a reserva. A marca só é confirmada após decisão e processamento do comando. A migration deve ser aplicada antes de iniciar o worker (`npm run db:migrate:deploy`); o boot verifica a tabela.

A decisão e o comando já persistidos são reutilizados nas retentativas, com o mesmo `commandId` e prazo original. MQTT e PostgreSQL não compartilham transação: uma queda após publicar e antes de confirmar a marca pode retransmitir o mesmo comando; a deduplicação do terminal por `commandId` continua obrigatória. O modo demo mantém o adapter volátil, sem garantia de dedup após restart. ACKs continuam correlacionados de forma persistente por `TerminalCommand`.

`TerminalCommand` funciona como outbox (DT-13): `publishedAt` fica `NULL` até a entrega ao broker. Se a publicação falhar (ex.: a API sem broker no pedido QR), a decisão continua válida — o pedido responde `GRANTED` e a autorização não é consumida de novo. O worker roda um relay no boot e a cada `COMMAND_RELAY_INTERVAL_MS` (padrão **5 s**), **incondicionalmente**: o firmware da main não publica `status` nem tentativa de acesso antes da leitura, então presença de terminal não serve de gate para a recuperação. O relay publica as intenções pendentes ainda no prazo, com o mesmo `commandId` e `expiresAt`, após uma folga de 1,5 s desde a decisão para não disputar com o publicador original. Nunca publica comando vencido nem abertura para terminal ou local inativo.

Cada intenção é **reservada** antes da publicação (`UPDATE ... SET "publishedAt"` com `FOR UPDATE SKIP LOCKED`): duas réplicas do worker não publicam o mesmo comando. Se o publish falhar, a reserva volta para `NULL` e o próximo ciclo tenta de novo; uma reserva órfã (processo que morreu entre marcar e publicar) é retomada depois de 60 s. A entrega é *at-least-once*: o terminal deduplica por `commandId`, mas a janela dele guarda só **8 ids** — dentro do prazo de 10 s do comando isso basta, porque o relay tenta no máximo duas vezes com 5 s.

Custo no Neon: uma consulta por ciclo, ~12 SELECTs/min por réplica. Com o worker do Render sempre ligado pelo keep-alive, o Neon pode não suspender; é o preço de recuperar a entrega sem depender do firmware. O `status` retido continua alimentando apenas o push do QR (`onlineTerminals`), não o relay.

## Fluxo de exemplo (NFC)

1. O terminal publica `status online` (retido) ao conectar.
2. O terminal lê a tag e publica `nfc_read` em `access-events`.
3. O backend valida a tentativa e publica um `command` (`open` ou `deny`) em `commands`.
4. O terminal executa (servo, LED, buzzer) e publica o `ack` com o mesmo `commandId`.
5. O backend loga o ACK correlacionado.

## Versionamento

A `v` só sobe em mudança incompatível (campo removido ou com outro significado). Campos novos opcionais mantêm a `v: 1`; consumidores ignoram campos que não conhecem. Uma mudança de contrato atualiza este documento, o parser e o simulador no mesmo PR.

## Ambientes

| | Dev | Prod |
|---|---|---|
| Broker | Mosquitto do compose, `mqtt://localhost:1884`, sem TLS e sem credenciais | HiveMQ Cloud, `mqtts://…:8883`, usuário e senha |
| Variáveis | `MQTT_URL` (default já aponta para o dev) | `MQTT_URL`, `MQTT_USERNAME`, `MQTT_PASSWORD` |
