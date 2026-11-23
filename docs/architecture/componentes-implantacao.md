# Componentes e implantação

Peças do sistema, como elas conversam e onde cada uma roda em desenvolvimento e em produção. Conferido contra a `main` em 23/11/2026: `backend/src/main/` (composição da API e do worker), `firmware/src/`, `mobile/lib/features/`, `infra/docker-compose.dev.yml`, `render.yaml` e `.github/workflows/cd-backend.yml`.

## Diagrama de componentes

A API e o worker são **dois processos do mesmo código** (`backend/`), montados por composition roots diferentes. Os dois usam os mesmos casos de uso e o mesmo PostgreSQL. A API atende o app por HTTPS; o worker fica conectado ao broker o tempo todo.

```mermaid
flowchart LR
  subgraph APP["App Flutter · mobile/"]
    direction TB
    A_AUTH["auth · login e sessão"]
    A_SCAN["scanner · câmera do QR + GPS"]
    A_AUT["authorizations · minhas autorizações"]
    A_ADM["admin_users · admin_authorizations · locations"]
    A_PRO["profile"]
  end

  subgraph API["API Express/TS · server.ts"]
    direction TB
    R["Rotas /api/v1<br/>auth · users · authorizations<br/>access-events · credentials · locations"]
    MW["Middlewares<br/>JWT · admin · rate limit · CORS"]
    UC_API["Casos de uso<br/>RequestQrAccess · DecideAccess<br/>PublishCommand · CRUDs"]
    BUS_API["Barramento MQTT preguiçoso<br/>lazy-mqtt-message-bus"]
    R --> MW --> UC_API --> BUS_API
  end

  subgraph WRK["Worker MQTT · worker.ts"]
    direction TB
    ROUTER["TerminalMessageRouter<br/>access-events · acks · status"]
    H_EVT["HandleAccessEvent<br/>frescor 30 s + dedup"]
    H_ACK["HandleAck<br/>correlaciona commandId"]
    QRPUB["PublishQrCode<br/>a cada 20 s"]
    RELAY["DispatchPendingCommands<br/>relay da outbox a cada 5 s"]
    PURGE["Expurgos diários<br/>comandos e dedup"]
    HEALTH["/healthz + keep-alive"]
    ROUTER --> H_EVT & H_ACK
  end

  BROKER[("Broker MQTT")]
  DB[("PostgreSQL<br/>User · Authorization · Credential<br/>AccessEvent · Terminal · AccessLocation<br/>TerminalCommand · ProcessedAccessMessage")]

  subgraph TER["Terminal ESP32 · firmware/"]
    direction TB
    T_MQTT["mqtt · Wi-Fi, TLS, fila de comandos, ACK"]
    T_DISP["display · QR e status"]
    T_NFC["nfc · RC522"]
    T_DOOR["door · servo"]
    T_FB["feedback · LED e buzzer"]
    T_GPS["gps · esqueleto US-24"]
    T_CLK["clock_time · SNTP"]
  end

  APP -- "HTTPS REST + JWT" --> R
  UC_API -- "Prisma/pg" --> DB
  BUS_API -- "commands" --> BROKER
  H_EVT & H_ACK & RELAY -->|"pg"| DB
  QRPUB & RELAY & H_EVT -->|"qr · commands"| BROKER
  BROKER -- "access-events · acks · status" --> ROUTER
  BROKER -- "qr · commands" --> T_MQTT
  T_MQTT -- "access-events · acks" --> BROKER
  T_NFC --> T_MQTT
  T_MQTT --> T_DOOR & T_FB & T_DISP

  classDef pendente stroke-dasharray: 5 5
  class T_GPS pendente
```

### Responsabilidade de cada componente

| Componente | Faz | Não faz |
|---|---|---|
| App Flutter | Login, leitura do QR pela câmera, envio do token + posição GPS, telas de administração e histórico | Não decide acesso nem fala MQTT |
| API (Vercel) | Autentica, valida o pedido QR, decide, grava evento + consumo + comando na mesma transação e tenta publicar o comando | Não recebe mensagens do terminal |
| Worker (Render) | Recebe tentativas NFC, ACKs e status; publica QR rotativo e comandos; reentrega comandos pendentes (outbox) | Não atende o app |
| Broker | Entrega as mensagens MQTT v1 com QoS 1 e TLS em produção | Não guarda comandos (sem retain) |
| PostgreSQL | Fonte única de usuários, autorizações, eventos, outbox de comandos (`TerminalCommand`) e dedup (`ProcessedAccessMessage`) | — |
| Terminal ESP32 | Mostra o QR, lê a tag, executa o comando válido, sinaliza e confirma com ACK | Nunca decide acesso. Sem hora confiável, recusa o comando (`clock_unsynced`) |

Tópicos, payloads e QoS: [`contratos-mqtt.md`](contratos-mqtt.md). Tabelas: [`modelo-dados.md`](modelo-dados.md). Camadas internas do backend: [`caso-de-uso-modelo.md`](caso-de-uso-modelo.md).

## Implantação em desenvolvimento

Tudo roda na máquina do desenvolvedor. Broker e banco sobem pelo compose. API e worker rodam com `npm` dentro de `backend/`. O terminal pode ser o simulador Node ou o firmware no Wokwi ou no ESP32 da bancada.

```mermaid
flowchart LR
  subgraph DEV["Máquina do desenvolvedor"]
    direction TB
    subgraph DC["Docker Compose · infra/docker-compose.dev.yml"]
      MOS[("Mosquitto 2<br/>host 1884 → 1883<br/>sem TLS")]
      PG[("Postgres 17<br/>host 5436 → 5432")]
    end
    API_DEV["API<br/>npm run dev · server.ts"]
    WRK_DEV["Processo MQTT<br/>npm run mqtt:consumer"]
    SIM["Terminal simulado<br/>npm run sim:terminal"]
    APP_DEV["App Flutter<br/>emulador ou aparelho"]
  end
  WOK["Wokwi ou ESP32 de bancada<br/>firmware PlatformIO"]

  APP_DEV -- "HTTP" --> API_DEV
  API_DEV -- "SQL" --> PG
  WRK_DEV -- "SQL" --> PG
  API_DEV -- "MQTT" --> MOS
  WRK_DEV -- "MQTT" --> MOS
  SIM -- "MQTT" --> MOS
  WOK -. "MQTT" .-> MOS
```

Passo a passo: [`../guides/como-rodar.md`](../guides/como-rodar.md).

## Implantação em produção

```mermaid
flowchart LR
  GH["GitHub Actions<br/>cd-backend.yml no push da main"]

  subgraph VER["Vercel"]
    API_P["API Express<br/>abp-4-sistema-controle-acesso.vercel.app"]
  end

  subgraph REN["Render · plano free"]
    WRK_P["abp4-mqtt-worker<br/>node dist/main/worker.js<br/>/healthz + self-ping 10 min"]
  end

  subgraph NEON["Neon"]
    PG_P[("PostgreSQL")]
  end

  subgraph EMQX["EMQX Cloud Serverless"]
    BR_P[("Broker MQTT<br/>TLS 8883 + usuário e senha")]
  end

  PHONE["App Android<br/>aparelho do usuário"]
  ESP["Terminal ESP32<br/>MQTT_USE_TLS 1 · CA do broker"]

  GH -- "deploy" --> API_P
  PHONE -- "HTTPS + JWT" --> API_P
  API_P -- "SQL/TLS" --> PG_P
  WRK_P -- "SQL/TLS" --> PG_P
  API_P -- "mqtts" --> BR_P
  WRK_P -- "mqtts" --> BR_P
  ESP -- "mqtts" --> BR_P
```

| Peça | Onde | Como é publicada | Observado |
|---|---|---|---|
| API | Vercel | CD do GitHub Actions a cada push na `main` | `/health` com `database: ok` (11/11) |
| Worker | Render (`render.yaml`) | Blueprint; segredos no painel (`sync: false`) | LIVE com `mqtt conectado` no EMQX TLS (11/11, [`us-37.md`](../entrega/evidencias/us-37.md)) |
| Banco | Neon | `prisma migrate deploy` no CD da API, antes da promoção | — |
| Broker | EMQX Cloud Serverless | Painel do EMQX | TLS 8883 |
| Terminal | ESP32 físico | Build PlatformIO com `MQTT_USE_TLS 1` | Conexão e certificado validados no ESP32 (06/11, [`dt-06.md`](../entrega/evidencias/dt-06.md)) |
| App | Android | APK gerado e validado no `ci-mobile` (DT-10) | Executado em aparelho físico ([`us-29-aparelho.md`](../entrega/evidencias/us-29-aparelho.md)) |

Limites que valem para produção:

- **O relay da outbox roda só entre 18:45 e 23:05**, no fuso `America/Sao_Paulo` (DT-21). Fora da janela, comando que falhou na primeira publicação não é reentregue (e já teria vencido os 10 s de prazo).
- **O Render free dorme sem tráfego.** O self-ping de 10 min mantém o worker acordado; a continuidade não foi medida.
- **Uma réplica de worker é o caso previsto**, mas o relay e a dedup usam reserva no banco e aguentam duas.

Detalhes de deploy: [`../guides/deploy.md`](../guides/deploy.md) e [`adr/001-provisionamento-vercel-neon.md`](adr/001-provisionamento-vercel-neon.md).
