# Sequências de acesso

Ordem das mensagens nos fluxos que envolvem o terminal: a rotação do QR, o acesso por QR, o acesso por NFC (tag física e celular) e a entrega do comando até o ACK, que é comum aos dois métodos. Cada passo cita a classe ou constante que o implementa na `main` em `349575d` (24/11/2026), para que o diagrama possa ser conferido contra o código.

## Prazos e proteções que aparecem nos fluxos

| Regra | Valor | Onde está |
|---|---|---|
| Validade do QR | 25 s | `QR_TTL_MS` em `backend/src/domain/terminal/messages.ts` |
| Intervalo de publicação do QR | 20 s, QoS 0 | `QR_INTERVAL_MS` em `backend/src/main/mqtt/worker-runtime.ts` |
| Validade da prova NFC do celular | 60 s, uso único | `NFC_CREDENTIAL_TTL_MS` em `issue-nfc-credential.use-case.ts`, `Credential.consumedAt` |
| Prazo do comando | 10 s a partir da decisão | `COMMAND_TTL_MS` em `messages.ts` |
| Frescor da tentativa NFC | idade abaixo de 30 s e até 5 s no futuro | `event-freshness.ts`, checado no parser e no caso de uso |
| Dedup da tentativa NFC | por `messageId`, com reserva no PostgreSQL | `ProcessedAccessMessage`, `postgres-event-deduplicator.ts` |
| Dedup do ACK | por `messageId`, em memória do worker | `SeenMessages` em `mqtt-composition-root.ts` |
| Dedup do comando no terminal | últimos 8 `commandId` | `kCapacity` em `firmware/include/command.h` |
| Relay da outbox | a cada 5 s, só entre 18:45 e 23:05 | `COMMAND_RELAY_INTERVAL_MS`, `RELAY_WINDOW_*` (DT-21) |
| Idade mínima da decisão antes do relay | 1,5 s | `DISPATCH_GRACE_MS` |
| Republicação sem ACK (e reserva órfã) | depois de 5 s | `CLAIM_STALE_MS` com `"publishedAt" < now - 5 s AND "ackStatus" IS NULL` em `postgres-command-store.ts` |
| Espera pelo PUBACK do broker | 3 s | `PUBLISH_TIMEOUT_MS` |

## 1. Rotação do QR no terminal

O worker só publica QR para terminais que ele considera online. Sem o heartbeat da US-24, isso acontece quando o terminal envia uma tentativa NFC recente, ou quando o simulador publica `status: online`. A lista fica em memória: se o worker reiniciar, o terminal só volta a receber QR depois de uma nova tentativa ou de um novo status.

```mermaid
sequenceDiagram
  autonumber
  participant T as Terminal ESP32
  participant B as Broker MQTT
  participant W as Worker MQTT

  Note over T,W: Presença vem do status online (US-24, pendente no firmware) ou de qualquer tentativa NFC recente
  T--)B: terminals/{id}/status online com LWT offline (pendente US-24)
  B--)W: status
  W->>W: TerminalMessageRouter marca o terminal online
  loop a cada 20 s para cada terminal online
    W->>W: IssueQrCredential assina o token com HMAC (v1, ou 41 dígitos com QR_COMPACT_ENABLED)
    W->>B: terminals/{id}/qr com token e expiresAt (QoS 0)
    B->>T: qr
    T->>T: readQr confere v, terminalId, token e expiresAt
    T->>T: display mostra o QR enquanto não vence e o relógio SNTP é confiável
  end
  Note over T: payload de QR inválido não apaga o último QR válido
```

## 2. Acesso por QR

O app lê o QR do display e manda o pedido por HTTPS. A API decide e grava tudo numa transação. A entrega do comando até o ACK segue a seção 4.

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant A as App Flutter
  participant API as API Vercel
  participant DB as PostgreSQL
  participant B as Broker MQTT

  U->>A: aponta a câmera para o QR do terminal
  A->>A: lê o token e a posição GPS do aparelho
  A->>API: POST /api/v1/access-events/qr com JWT, token, posição e requestId
  API->>API: rate limit e requireAuth
  API->>DB: transação do DecideAccessUseCase
  activate DB
  alt requestId já usado na mesma tentativa
    DB-->>API: evento existente
    Note over API: devolve o mesmo evento sem consumir a autorização de novo
  else primeira vez
    API->>API: valida assinatura do token, terminal e 25 s
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
    Note over A: nenhum comando vai ao terminal no QR negado
  else GRANTED
    API->>DB: canDispatch confere terminal e local ativos (senão responde 503)
    API->>B: terminals/{id}/commands open (QoS 1, espera PUBACK até 3 s)
    alt broker confirmou
      API->>DB: markPublished grava publishedAt
      API-->>A: 200 liberado, commandPublished true
    else falha de transporte
      API-->>A: 200 liberado, commandPublished false
      Note over API,DB: publishedAt fica nulo e o relay do worker entrega
    end
    Note over B: entrega ao terminal, relay e ACK na seção 4
  end
```

## 3. Acesso por NFC: tag física ou celular

As duas formas publicam no mesmo tópico `terminals/{id}/access-events` e passam pelo mesmo caso de uso. A tag manda o UID (`nfc_read`). O celular manda uma prova de 128 bits emitida pela API, válida por 60 s e de uso único (`nfc_hce_read`), nunca o UID do aparelho.

A tentativa só é aceita enquanto é recente. O frescor é conferido **quatro vezes**: no parser, no início do caso de uso, depois da reserva de dedup e dentro da transação, depois dos locks. Uma tentativa velha é descartada no parser e nem marca o terminal como online. O terminal não guarda tentativas para mandar depois: sem rede ou sem hora confiável, a pessoa precisa reapresentar a tag (fila offline é a US-25).

A leitura da prova HCE pelo ESP32 está no firmware (`SELECT AID` ISO-DEP, prova de 16 bytes + `9000`, publicação de `nfc_hce_read`).

```mermaid
sequenceDiagram
  autonumber
  actor U as Usuário
  participant A as App Flutter
  participant API as API Vercel
  participant T as Terminal ESP32
  participant B as Broker MQTT
  participant W as Worker MQTT
  participant DB as PostgreSQL

  alt tag física
    U->>T: encosta a tag no RC522
    T->>T: lê o UID, uma tentativa por apresentação da tag
  else celular com HCE
    U->>A: abre Acesso por NFC
    A->>API: POST /api/v1/access-credentials/nfc com JWT
    API->>DB: grava Credential NFC_HCE só com o hash da prova, válida por 60 s
    API-->>A: 201 com token e expiresAt
    A->>A: NfcCredentialStore guarda a prova em memória e renova com 5 s restantes
    U->>T: encosta o celular no RC522
    T->>A: SELECT AID F041425034444D01
    A-->>T: 16 bytes da prova + 9000
  end

  alt sem MQTT ou sem hora SNTP confiável
    T->>T: não publica e pede para reapresentar
  else pronto
    T->>B: access-events nfc_read com uid ou nfc_hce_read com credentialToken (QoS 1)
    T->>T: display mostra leitura em andamento
    B->>W: access-events
    alt parser: payload inválido ou fora da janela de 30 s
      W->>W: descarta sem marcar presença
    else payload válido e recente
      W->>W: marca o terminal online
      W->>W: HandleAccessEvent confere o frescor
      W->>DB: reserva o messageId em ProcessedAccessMessage
      alt messageId já processado
        W->>W: descarta como duplicate
      else reserva de outra réplica em andamento
        W->>W: descarta como busy
      else reserva obtida
        W->>W: confere o frescor de novo
        W->>DB: transação do DecideAccessUseCase com occurredAt do terminal
        DB-->>W: credencial pelo hash do UID ou da prova, autorização e usos
        W->>W: confere o frescor depois dos locks (stale descarta sem comando)
        W->>W: credencial válida, não revogada, dentro da validade e, no celular, ainda não consumida
        opt prova do celular aceita
          W->>DB: consome a prova antes da autorização (já consumida vira INVALID_CREDENTIAL)
        end
        W->>DB: consome a autorização se liberado e grava AccessEvent
        W->>DB: grava ou reaproveita TerminalCommand open ou deny (prazo decisão + 10 s)
        alt prazo vencido antes de publicar
          W->>W: não publica, status expired
        else dentro do prazo
          W->>B: terminals/{id}/commands open ou deny
          Note over B: entrega ao terminal, relay e ACK na seção 4
        end
      end
    end
  end
```

## 4. Entrega do comando, relay da outbox e ACK

Vale para o QR (comando publicado pela API) e para o NFC (publicado pelo worker). Todo comando fica em `TerminalCommand` com `commandId` e `expiresAt` fixos. O relay do worker republica o **mesmo** comando enquanto não houver ACK e o prazo não vencer, inclusive quando a primeira publicação deu certo mas o ACK não chegou em 5 s. Por isso o terminal deduplica por `commandId`.

```mermaid
sequenceDiagram
  autonumber
  participant P as API no QR ou worker no NFC
  participant DB as PostgreSQL
  participant B as Broker MQTT
  participant T as Terminal ESP32
  participant W as Worker MQTT

  Note over P,DB: TerminalCommand já gravado com commandId e expiresAt = decisão + 10 s
  P->>B: commands (QoS 1, espera PUBACK até 3 s)
  alt broker confirmou
    P->>DB: markPublished grava publishedAt
  else falha de transporte
    Note over P,DB: publishedAt fica nulo
  end

  B->>T: commands
  T->>T: fila de até 8 comandos, um por vez com a porta em idle
  alt commandId entre os últimos 8
    T->>T: não atua de novo e repete o status anterior com reason duplicate
  else relógio sem SNTP
    T->>T: rejected clock_unsynced
  else expiresAt já passou
    T->>T: expired
  else porta ocupada
    T->>T: rejected door_busy
  else open válido
    T->>T: abre a porta no perfil com servo, LED verde e buzzer
  else deny válido
    T->>T: tela de negado, LED vermelho e buzzer
  end

  T->>B: terminals/{id}/acks com commandId e status (QoS 1, uma tentativa)
  alt ACK entregue
    B->>W: acks
    W->>W: HandleAck descarta ACK repetido pelo messageId
    W->>DB: grava ackStatus pelo commandId e terminal
  else publicação do ACK falhou
    T->>T: descarta o ACK e segue
  end

  loop relay a cada 5 s, de 18:45 às 23:05, enquanto ackStatus for nulo e expiresAt não passar
    W->>DB: reserva 1 comando com publishedAt nulo ou mais antigo que 5 s
    opt comando open
      W->>DB: canDispatch (terminal ou local inativo deixa o comando retido)
    end
    W->>B: republica o mesmo commandId e o mesmo expiresAt
    W->>DB: markPublished
    B->>T: commands
    T->>T: executa se for a primeira entrega, senão só repete o status anterior
    T->>B: acks
    B->>W: acks
    W->>DB: grava ackStatus se ainda estava nulo
  end
```

## O que os diagramas não garantem

- **Abertura física.** A decisão `GRANTED` é autorização. A confirmação de que a porta abriu é o ACK `executed`, e o servo físico ainda não foi demonstrado de ponta a ponta (US-34).
- **Heartbeat, LWT e leitura HCE no ESP32.** Desenhados, mas pendentes no firmware do repositório (US-24 e #77).
- **Entrega garantida.** MQTT com QoS 1 é *at-least-once*, e o terminal tenta publicar o ACK uma vez só. Quem cobre um ACK perdido é a republicação do relay, que só acontece dentro dos 10 s do comando e dentro da janela de operação. Por isso há dedup nos três pontos: tentativa, comando e ACK.

Contratos dos payloads em [`contratos-mqtt.md`](contratos-mqtt.md). Visão geral em [`visao-geral.md`](visao-geral.md).
