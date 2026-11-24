# Casos de uso

Quem usa o sistema e o que cada um consegue fazer, conferido contra as rotas da API (`backend/src/main/http/routes/`), os papéis do banco (`UserRole` em `backend/prisma/schema.prisma`), o app (`mobile/lib/features/`) e o firmware (`firmware/src/`). Retrato da `main` em `349575d` (24/11/2026).

Os perfis de pessoa são os do banco: **Administrador** (`ADMIN`), **Condômino** (`RESIDENT`) e **Visitante** (`VISITOR`). Os três são **usuários autenticados** e herdam os mesmos casos de uso de acesso; o administrador soma a gestão. O **Terminal** (ESP32) é um ator de sistema: fala só MQTT e nunca decide acesso sozinho.

## Diagrama

O Mermaid não tem notação UML própria de casos de uso. Aqui os atores são os nós retangulares fora da fronteira, os casos de uso são as elipses dentro de `Sistema de Controle de Acesso`, a seta `especializa` é a generalização entre atores, e as linhas tracejadas com borda tracejada marcam o que **não está implementado no repositório**.

```mermaid
flowchart LR
  USR["Usuário autenticado"]
  COND["Condômino<br/>RESIDENT"]
  VIS["Visitante<br/>VISITOR"]
  ADM["Administrador<br/>ADMIN"]
  TER["Terminal ESP32<br/>ator de sistema"]

  COND -->|especializa| USR
  VIS -->|especializa| USR
  ADM -->|especializa| USR

  subgraph SIS["Sistema de Controle de Acesso"]
    direction TB
    UC1(["Entrar no app"])
    UC2(["Editar o próprio perfil"])
    UC3(["Consultar minhas autorizações"])
    UC4(["Consultar meu histórico de acessos"])
    UC5(["Acessar por QR Code"])
    UC6(["Acessar por tag NFC"])
    UC7(["Acessar com NFC do celular"])
    UC8(["Gerar prova NFC de 60 s"])
    UC9(["Gerenciar usuários"])
    UC10(["Criar, consultar e cancelar autorizações"])
    UC11(["Cadastrar locais"])
    UC12(["Consultar histórico geral"])
    UC13(["Exibir QR rotativo"])
    UC14(["Ler tag e enviar a tentativa"])
    UC15(["Ler a prova HCE do celular"])
    UC16(["Executar comando e confirmar com ACK"])
    UC17(["Informar presença por heartbeat"])
    INC1(["Validar geofence de até 100 m"])
    INC2(["Decidir acesso no backend"])
  end

  USR --- UC1 & UC2 & UC3 & UC4 & UC5 & UC6 & UC7
  ADM --- UC9 & UC10 & UC11 & UC12

  UC5 -.->|inclui| INC1
  UC5 -.->|inclui| INC2
  UC6 -.->|inclui| INC2
  UC7 -.->|inclui| UC8
  UC7 -.->|inclui| INC2
  UC5 -.->|depende de| UC13
  UC6 -.->|depende de| UC14
  UC7 -.->|depende de| UC15
  INC2 -.->|gera| UC16

  TER --- UC13 & UC14 & UC15 & UC16
  TER -.- UC17

  classDef pendente stroke-dasharray: 5 5
  class UC17 pendente
```

## Onde cada caso de uso está

| Caso de uso | Ator | Entrada no sistema | Story |
|---|---|---|---|
| Entrar no app | usuário autenticado | `POST /api/v1/auth/login`, `GET /api/v1/auth/me` | US-14, US-27 |
| Editar o próprio perfil | usuário autenticado | `PATCH /api/v1/me` | US-14 |
| Consultar minhas autorizações | usuário autenticado | `GET /api/v1/me/authorizations` | US-18, US-28 |
| Consultar meu histórico de acessos | usuário autenticado | `GET /api/v1/me/access-events` | US-21 |
| Acessar por QR Code | usuário autenticado com autorização | app escaneia o QR do terminal e chama `POST /api/v1/access-events/qr` | US-19, US-20, US-29 |
| Acessar por tag NFC | usuário com tag cadastrada e autorização | tag no RC522 → MQTT `terminals/{id}/access-events` (`nfc_read`) | US-23 |
| Acessar com NFC do celular | usuário autenticado com autorização (Android com HCE) | tela `/nfc` do app; o celular encostado no RC522 entrega a prova → MQTT `nfc_hce_read` | #77 |
| Gerar prova NFC de 60 s | incluído no acesso pelo celular | `POST /api/v1/access-credentials/nfc` (`IssueNfcCredentialUseCase`) | #77 |
| Validar geofence de até 100 m | incluído no QR | `decideAccess` com `min(location.radiusMeters, 100)` | US-20, DT-23 |
| Decidir acesso no backend | incluído no QR e nos dois NFC | `DecideAccessUseCase` (`backend/src/application/access/`) | US-19, US-23, #77 |
| Gerenciar usuários | administrador | `GET/POST /api/v1/users`, `GET/PATCH/DELETE /api/v1/users/:id` | US-15, US-31 |
| Criar, consultar e cancelar autorizações | administrador | `GET/POST /api/v1/authorizations`, `POST /api/v1/authorizations/:id/cancel` | US-16, US-17, US-30 |
| Cadastrar locais | administrador (listar com `GET /api/v1/locations` vale para qualquer usuário autenticado) | `POST /api/v1/locations` | US-39 |
| Consultar histórico geral | administrador | `GET /api/v1/access-events` | US-21, US-31 |
| Exibir QR rotativo | terminal | recebe `terminals/{id}/qr` do worker e desenha no display | US-22, #73 |
| Ler tag e enviar a tentativa | terminal | `terminal_nfc::update` → `terminal_mqtt::publishNfc` | US-23 |
| Ler a prova HCE do celular | terminal | ISO-DEP: o firmware envia o `SELECT AID` e publica `nfc_hce_read` (`firmware/src/modules/nfc.cpp`) | #77, #79 |
| Executar comando e confirmar com ACK | terminal | recebe `terminals/{id}/commands`, publica `terminals/{id}/acks` | US-08, US-26 |
| Informar presença por heartbeat | terminal | `terminals/{id}/status` com LWT — **pendente** | US-24 |

## Limites e decisões que o diagrama reflete

- **Quem cria autorização é só o administrador.** O app descreve o visitante como "acesso temporário liberado por um morador", mas a rota `POST /authorizations` exige `requireAdmin`. O condômino não cria autorização para visitante. O diagrama segue o código.
- **A tag física não é cadastrada pelo app nem pela API.** A credencial `NFC` entra pelo seed ou pelos scripts de provisionamento (`backend/prisma/seed.ts`, `provision.ts`). Já a prova do celular (`NFC_HCE`) é emitida pela API a cada uso, vale 60 s e é consumida no primeiro acesso aceito.
- **O NFC do celular está completo.** A API, o worker, o app (serviço HCE `NfcHceService`, AID `F041425034444D01`) e a leitura ISO-DEP pelo ESP32 estão na `main` (#77 e #79). O teste real registrou `NFC_HCE GRANTED` com a prova consumida e o ACK do terminal.
- **O QR negado não chega ao terminal.** No QR, o resultado volta para o app na resposta HTTP e só a decisão `GRANTED` grava um comando `open`. No NFC, o worker publica `open` ou `deny`, porque o terminal é a única interface de quem encostou a tag ou o celular.
- **Heartbeat pendente (US-24).** O firmware ainda não publica `status` nem registra LWT. Hoje o worker passa a considerar o terminal online quando recebe dele uma tentativa NFC recente (`TerminalMessageRouter`), e só então envia o QR rotativo. Em simulação, o status é publicado pelo `sim-terminal`.

Fluxos detalhados em [`sequencias.md`](sequencias.md) e peças do sistema em [`componentes-implantacao.md`](componentes-implantacao.md).
