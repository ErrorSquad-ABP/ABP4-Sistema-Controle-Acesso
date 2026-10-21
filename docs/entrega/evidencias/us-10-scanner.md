# Evidência — US-10 (login & scanner) · 21/10/2026

Branch `feat/us-10-scanner-geo`, PR #20, commit de merge `b1b7550`.

## Validação executada

- `flutter analyze`: sem issues.
- `flutter test`: **33/33**.
- `dart format --output=none --set-exit-if-changed`: 0 alterações.
- `flutter build web`: sucesso.
- CI: `ci-mobile-check` verde.

## O que foi entregue

- Scanner QR com `mobile_scanner` e estados de permissão/erro.
- Geolocalização com `geolocator` no momento da leitura.
- Feedback de sucesso/erro com `successSoft`/`errorSoft` e texto `onSoft` (AA).
- Material em pt-BR (`flutter_localizations`, `supportedLocales`, `locale`).
- Rota `/scan`, entrada na Home e modo demonstração explícito no login (sem autenticar).
- Nenhuma liberação de acesso ou chamada ao backend (fronteira da US-29).

## Limites

- Leitura com câmera real não foi validada nesta máquina (sem dispositivo no ambiente); a página é demonstrável no navegador/aparelho com câmera.
- APK Android não gerado (sem SDK); dívida DT-10.
