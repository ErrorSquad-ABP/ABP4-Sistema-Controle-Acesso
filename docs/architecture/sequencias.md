# Sequências de acesso

Ordem das mensagens nos três fluxos que envolvem o terminal: a rotação do QR, o acesso por QR e o acesso por NFC. Cada passo cita a classe ou constante que o implementa na `main` (23/11/2026), para que o diagrama possa ser conferido contra o código.

## Prazos e proteções que aparecem nos fluxos

| Regra | Valor | Onde está |
|---|---|---|
| Validade do QR | 25 s | `QR_TTL_MS` em `backend/src/domain/terminal/messages.ts` |
| Intervalo de publicação do QR | 20 s | `QR_INTERVAL_MS` em `backend/src/main/mqtt/worker-runtime.ts` |
| Prazo do comando | 10 s a partir da decisão | `COMMAND_TTL_MS` em `messages.ts` |
| Frescor da tentativa NFC | até 30 s de idade e até 5 s no futuro | `event-freshness.ts` |
| Dedup da tentativa NFC | por `messageId`, com reserva no PostgreSQL | `ProcessedAccessMessage`, `postgres-event-deduplicator.ts` |
| Dedup do ACK | por `messageId`, em memória do worker | `SeenMessages` |
| Dedup do comando no terminal | últimos 8 `commandId` | `kCapacity` em `firmware/include/command.h` |
| Relay da outbox | a cada 5 s, só entre 18:45 e 23:05 | `COMMAND_RELAY_INTERVAL_MS`, DT-21 |
| Folga antes de republicar | 1,5 s | `DISPATCH_GRACE_MS` |
| Reserva órfã do relay | expira em 5 s | `CLAIM_STALE_MS` |
| Espera pelo PUBACK do broker | 3 s | `PUBLISH_TIMEOUT_MS` |

## 1. Rotação do QR no terminal

O worker só publica QR para terminais que ele considera online. Sem o heartbeat da US-24, isso acontece quando o terminal envia uma tentativa NFC, ou quando o simulador publica `status: online`.

```mermaid
sequenceDiagram
  autonumber
  participant T as Terminal ESP32
  participant B as Broker MQTT
  participant W as Worker MQTT
  participant DB as PostgreSQL

  Note over T,W: Presença: status online (US-24, pendente no firmware) ou qualquer tentativa NFC
  T--)B: terminals/{id}/status online + LWT offline (pendente US-24)
  B--)W: status
  W->>W: TerminalMessageRouter marca o terminal online
  loop a cada 20 s para cada terminal online
    W->>W: IssueQrCredential assina o token (validade 25 s)
    W->>B: terminals/{id}/qr com token e expiresAt
    B->>T: qr
    T->>T: readQr confere v, terminalId e expiresAt
    T->>T: display mostra o QR se o relógio SNTP for confiável
  end
  Note over T: QR inválido não apaga o último QR válido
```

## 2. Acesso por QR

O app lê o QR do display e manda o pedido por HTTPS. A API decide e grava tudo numa transação. Se a publicação do comando falhar, o relay do worker entrega o **mesmo** comando, com o mesmo `commandId` e o mesmo prazo.

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant A as App Flutter
  participant API as API Vercel
  participant DB as PostgreSQL
  participant B as Broker MQTT
  participant T as Terminal ESP32
  participant W as Worker MQTT

  U->>A: aponta a câmera para o QR do terminal
  A->>A: lê o token e a posição GPS do aparelho
  A->>API: POST /api/v1/access-events/qr com JWT, token, posição e requestId
  API->>API: requireAuth e rate limit
  API->>DB: transação do DecideAccessUseCase
  activate DB
  DB-->>API: evento já existe com o mesmo requestId?
  alt mesmo requestId
    API-->>A: devolve o mesmo evento sem consumir de novo
  else primeira vez
    API->>API: valida token, terminal e 25 s
    API->>API: valida usuário, autorização, usos e geofence min(raio, 100 m)
    API->>DB: consome a autorização
    API->>DB: grava AccessEvent GRANTED ou DENIED
    opt decisão GRANTED
      API->>DB: grava TerminalCommand open com expiresAt = decisão + 10 s
    end
  end
  deactivate DB

  alt DENIED
    API-->>A: 200 negado com o motivo
    Note over T: nenhum comando vai ao terminal no QR negado
  else GRANTED
    API->>DB: canDispatch confere terminal e local ativos (senão responde 503)
    API->>B: terminals/{id}/commands QoS 1 (espera PUBACK até 3 s)
    alt broker confirmou
      API->>DB: markPublished
      API-->>A: liberado, commandPublished true
    else falha de transporte
      API-->>A: liberado, commandPublished false
      Note over W,DB: relay da outbox, a cada 5 s dentro da janela 18:45 às 23:05
      W->>DB: reserva um comando pendente, não vencido e com mais de 1,5 s
      W->>B: publica o mesmo commandId e o mesmo expiresAt
      W->>DB: markPublished (reserva órfã expira em 5 s)
    end
    B->>T: commands
    T->>T: fila de até 8 comandos, processa um por vez com a porta em idle
    alt commandId entre os últimos 8
      T->>T: não atua de novo, repete o status anterior com reason duplicate
    else relógio sem SNTP
      T->>T: rejected clock_unsynced
    else expiresAt já passou
      T->>T: expired
    else porta ocupada
      T->>T: rejected door_busy
    else válido
      T->>T: abre a porta, LED verde e buzzer
    end
    T->>B: terminals/{id}/acks com commandId e status
    B->>W: acks
    W->>W: HandleAck descarta ACK repetido pelo messageId
    W->>DB: correlaciona pelo commandId e terminal
  end
```

## 3. Acesso por NFC

A tentativa vai do terminal ao worker por MQTT. Ela só é aceita enquanto é recente: o worker confere o frescor antes da dedup, depois da reserva e de novo dentro da transação de decisão. O terminal não guarda tentativas para mandar depois: sem rede ou sem hora confiável, a leitura é recusada e a pessoa reapresenta a tag (fila offline é a US-25).

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant T as Terminal ESP32
  participant B as Broker MQTT
  participant W as Worker MQTT
  participant DB as PostgreSQL

  U->>T: encosta a tag no RC522
  T->>T: lê o UID, uma tentativa por apresentação da tag
  alt sem MQTT ou sem hora SNTP confiável
    T->>T: não publica e pede para reapresentar a tag
  else pronto
    T->>B: terminals/{id}/access-events nfc_read com messageId, timestamp e uid (QoS 1)
    T->>T: display mostra leitura em andamento
    B->>W: access-events
    W->>W: valida o payload e marca o terminal online
    alt idade acima de 30 s ou mais de 5 s no futuro
      W->>W: descarta como stale, sem comando
    else recente
      W->>DB: reserva o messageId em ProcessedAccessMessage
      alt messageId já processado
        W->>W: descarta como duplicate
      else reserva de outra réplica em andamento
        W->>W: descarta como busy
      else reserva obtida
        W->>W: confere o frescor de novo
        W->>DB: transação do DecideAccessUseCase com occurredAt do terminal
        DB-->>W: credencial pelo hash do UID, autorização e usos
        W->>W: confere o frescor depois dos locks
        W->>DB: grava AccessEvent e, se GRANTED, consome e grava TerminalCommand
        W->>DB: grava ou reaproveita o comando open ou deny (prazo decisão + 10 s)
        alt prazo vencido antes de publicar
          W->>W: não publica, status expired
        else dentro do prazo
          W->>B: terminals/{id}/commands open ou deny
          B->>T: commands
          T->>T: mesma checagem do QR: dedup de 8 commandId, relógio, prazo e porta
          T->>T: open abre a porta com LED verde, deny mostra negado com LED vermelho
          T->>B: acks
          B->>W: acks
          W->>DB: correlaciona o ACK pelo commandId
        end
      end
    end
  end
```

## O que os diagramas não garantem

- **Abertura física.** A decisão `GRANTED` é autorização. A confirmação de que a porta abriu é o ACK `executed`, e o servo físico ainda não foi demonstrado de ponta a ponta (US-34).
- **Heartbeat e LWT.** Desenhados como pendentes: o firmware da `main` não publica `status` (US-24).
- **Entrega garantida.** MQTT com QoS 1 é *at-least-once*. Por isso há dedup nos três pontos (tentativa, comando e ACK). O relay só cobre comandos ainda dentro dos 10 s.

Contratos dos payloads em [`contratos-mqtt.md`](contratos-mqtt.md). Visão geral em [`visao-geral.md`](visao-geral.md).
