# Modelo de dados v1

Diagrama entidade-relacionamento do backend, alinhado ao [`schema.prisma`](../../backend/prisma/schema.prisma) e ao contrato REST v1 (US-06). IDs são UUIDs; datas são armazenadas como `DateTime` no PostgreSQL. Campos marcados como FK representam as relações entre entidades.

Os nomes de tabela e de campo acompanham o contrato REST (ex.: `active`, `startsAt`, `usedCount`, `locationId`, `canceledAt`) para o mapeamento entre API e banco não depender de tradução.

```mermaid
erDiagram
    USER {
        UUID id PK
        String name
        String email UK
        String passwordHash
        UserRole role
        Boolean active
        DateTime createdAt
        DateTime updatedAt
    }

    ACCESS_LOCATION {
        UUID id PK
        String name
        String description "opcional"
        Decimal latitude
        Decimal longitude
        Integer radiusMeters
        Boolean isActive
        DateTime createdAt
        DateTime updatedAt
    }

    AUTHORIZATION {
        UUID id PK
        UUID userId FK
        UUID locationId FK
        UUID createdById FK "opcional"
        DateTime startsAt
        DateTime endsAt
        Integer maxUses
        Integer usedCount
        DateTime canceledAt "opcional"
        String cancelReason "opcional"
        DateTime createdAt
        DateTime updatedAt
    }

    CREDENTIAL {
        UUID id PK
        UUID userId FK
        CredentialType type
        String valueHash UK
        DateTime validFrom "opcional"
        DateTime validUntil "opcional"
        DateTime revokedAt "opcional"
        DateTime createdAt
        DateTime updatedAt
    }

    ACCESS_EVENT {
        UUID id PK
        UUID userId FK "opcional"
        UUID authorizationId FK "opcional"
        UUID credentialId FK "opcional"
        UUID locationId FK "opcional"
        AccessMethod method
        AccessDecision decision
        String reason "opcional"
        Decimal latitude "opcional"
        Decimal longitude "opcional"
        Decimal distanceMeters "opcional"
        DateTime occurredAt
    }

    USER ||--o{ AUTHORIZATION : "recebe"
    USER o|--o{ AUTHORIZATION : "cria"
    ACCESS_LOCATION ||--o{ AUTHORIZATION : "define local"
    USER ||--o{ CREDENTIAL : "possui"
    USER o|--o{ ACCESS_EVENT : "associado a"
    AUTHORIZATION o|--o{ ACCESS_EVENT : "origina"
    CREDENTIAL o|--o{ ACCESS_EVENT : "utilizada em"
    ACCESS_LOCATION o|--o{ ACCESS_EVENT : "ocorre em"
```

## Situação da autorização

`SCHEDULED`, `ACTIVE`, `EXPIRED` e `CANCELED` **não são colunas**: a situação é derivada de `canceledAt`, `startsAt`/`endsAt` e `maxUses`/`usedCount`, na ordem abaixo.

1. `canceledAt` preenchido → `CANCELED`.
2. `usedCount >= maxUses` ou agora depois de `endsAt` → `EXPIRED`.
3. agora antes de `startsAt` → `SCHEDULED`.
4. caso contrário → `ACTIVE`.

Persistir só os fatos (janela, contador e cancelamento) evita linha `ACTIVE` vencida no banco e dispensa rotina agendada para virar `EXPIRED`.

## Regras e enums

- Cada autorização pertence a um usuário e a um local. `createdById` registra o administrador que a criou quando conhecido.
- `maxUses` é obrigatório (limite de utilizações na janela); `usedCount` começa em zero. `CancelAuthorizationRequest.reason` é gravado em `cancelReason`.
- Cada credencial pertence a um usuário. `valueHash` guarda o hash do token QR ou do UID NFC, e nunca o valor original.
- A senha é gravada no formato `scrypt$N$r$p$salt$hash` ([`password-hasher.ts`](../../backend/src/shared/password-hasher.ts)). Cadastro real (inclusive `npm run db:provision`) usa salt aleatório; a seed de demonstração usa salt determinístico para poder ser reexecutada. A seed demo só roda em banco local e nunca em produção; o primeiro administrador real vem de `db:provision` (ver [como rodar](../guides/como-rodar.md#seed-demo--provisionamento-real-dt-07)).
- Eventos preservam o resultado (`GRANTED` ou `DENIED`), método (`QR` ou `NFC`), motivo e coordenadas recebidas. As relações com usuário, autorização, credencial e local são opcionais para registrar tentativas sem identificação completa. O motivo segue o enum `DenialReason` do contrato e é `null` quando o acesso é concedido.
- `locationId` do evento é opcional no banco. A API só grava evento com local quando consegue resolver o terminal para um `AccessLocation` (US-19/US-20); o contrato REST devolve `location` obrigatório, então evento sem local é falha de dados, não um caso de uso.
- Exclusão de usuário, local e credencial referenciados por autorizações é restringida. Ao excluir uma entidade referenciada por um evento, a FK do evento é anulada para preservar o histórico.
- `UserRole`: `ADMIN`, `RESIDENT`, `VISITOR` · `CredentialType` e `AccessMethod`: `QR`, `NFC` · `AccessDecision`: `GRANTED`, `DENIED`.

## Campos espaciais

`AccessLocation.latitude` e `longitude` são coordenadas do local; `radiusMeters` define a distância máxima permitida para o geofence (100 m por padrão). As coordenadas e `distanceMeters` do evento registram a posição informada na tentativa de acesso.
