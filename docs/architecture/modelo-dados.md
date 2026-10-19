# Modelo de dados v1

Diagrama entidade-relacionamento do backend, alinhado ao [`schema.prisma`](../../backend/prisma/schema.prisma). IDs são UUIDs; datas são armazenadas como `DateTime` no PostgreSQL. Campos marcados como FK representam as relações entre entidades.

```mermaid
erDiagram
    USER {
        UUID id PK
        String name
        String email UK
        String passwordHash
        UserRole role
        Boolean isActive
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
        UUID accessLocationId FK
        UUID createdById FK "opcional"
        AuthorizationStatus status
        DateTime validFrom
        DateTime validUntil
        Integer maxUses "opcional"
        Integer usesCount
        DateTime cancelledAt "opcional"
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
        UUID accessLocationId FK "opcional"
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

## Regras e enums

- Cada autorização pertence a um usuário e a um local. `createdById` registra o administrador que a criou quando conhecido.
- Uma autorização pode ter limite de usos (`maxUses`); `usesCount` começa em zero. A validade fica entre `validFrom` e `validUntil`.
- Cada credencial pertence a um usuário. `valueHash` guarda o hash do token QR ou do UID NFC, e nunca o valor original.
- Eventos preservam o resultado (`ALLOWED` ou `DENIED`), método (`QR` ou `NFC`), motivo e coordenadas recebidas. As relações com usuário, autorização, credencial e local são opcionais para registrar tentativas sem identificação completa.
- Exclusão de usuário, local e credencial referenciados por autorizações é restringida. Ao excluir uma entidade referenciada por um evento, a FK do evento é anulada para preservar o histórico.
- `UserRole`: `USER`, `ADMIN` · `AuthorizationStatus`: `ACTIVE`, `CANCELLED` · `CredentialType` e `AccessMethod`: `QR`, `NFC` · `AccessDecision`: `ALLOWED`, `DENIED`.

## Campos espaciais

`AccessLocation.latitude` e `longitude` são coordenadas do local; `radiusMeters` define a distância máxima permitida para o geofence (100 m por padrão). As coordenadas e `distanceMeters` do evento registram a posição informada na tentativa de acesso.
