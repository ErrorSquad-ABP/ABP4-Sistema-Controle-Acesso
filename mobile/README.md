# mobile

App Flutter do usuário e da administração — Flutter 3.47 (Dart 3.13) + Riverpod 3 + go_router, alvo Android (US-09).

## Estrutura

```text
lib/
├─ main.dart                 ProviderScope + runApp
├─ app.dart                  MaterialApp.router: temas, themeMode, pt-BR e router via Riverpod
├─ core/
│  ├─ theme/                 tokens e ThemeData do design system
│  │  ├─ app_colors.dart     AppPalette (ThemeExtension): base monocromática + feedback
│  │  ├─ app_typography.dart escala Figtree (Display 32 … Micro 11)
│  │  ├─ app_spacing.dart    grid 8pt, margem 24, raios 12/16/pill, toque 56
│  │  ├─ app_theme.dart      AppTheme.light() / AppTheme.dark()
│  │  └─ theme_mode_provider.dart  aparência (sistema/claro/escuro)
│  ├─ widgets/feedback_banner.dart  aviso de estado (sucesso/erro/atenção) com contraste AA
│  └─ router/app_router.dart rotas (AppRoutes) + appRouterProvider
└─ features/                 uma pasta por feature (auth, scanner, authorizations, admin…)
   ├─ auth/                  login mock (US-06/US-10)
   ├─ home/                  tela inicial provisória do esqueleto
   └─ scanner/               leitura de QR + posição (US-10)
test/                        widget tests do app, do tema, do login e do scanner
assets/fonts/figtree/        Figtree 400/500/600/700 + OFL.txt
```

## Rodando

```bash
cd mobile
flutter pub get
flutter run -d chrome     # ou: flutter run (emulador/aparelho Android)
```

| Comando | O que faz |
|---|---|
| `flutter analyze` | lints (`flutter_lints` + regras extras em `analysis_options.yaml`) |
| `flutter test` | widget test do app e testes do tema |
| `dart format lib test` | formatação |
| `flutter build apk` | build Android (exige Android SDK) |
| `flutter build web` | build web |

O CI (`ci-mobile.yml`) roda `flutter pub get`, `flutter analyze` e `flutter test` em todo PR que mexe em `mobile/`.

## Tema

Espelha o design system **Monochrome Premium** do Figma ([`design/README.md`](../design/README.md)) nos dois modos.

- **Cores**: leia pelo tema, nunca com hex solto na tela — `Theme.of(context).colorScheme` para a base e `context.palette` (de `app_colors.dart`) para os tokens do projeto, inclusive feedback (`success`, `error`, `warning` e as versões `*Soft`).
- **Tipografia**: `Theme.of(context).textTheme` — `displaySmall` (Display 32), `headlineSmall` (Título 24), `titleLarge` (Cabeçalho 20), `bodyLarge`/`bodyMedium` (Corpo 16, primário/secundário), `bodySmall` (Legenda 13), `labelSmall` (Micro 11, escrever o texto em caixa alta).
- **Espaços e raios**: `AppSpacing` e `AppRadius`.
- **Componentes**: `FilledButton` = primário (cápsula preto↔branco), `OutlinedButton` = secundário, `TextButton` = ghost; `TextField`, `Card`, `Divider` e `NavigationBar` já saem no padrão.
- **Aparência**: segue o sistema; `ref.read(themeModeProvider.notifier).set(ThemeMode.dark)` troca (seletor do Perfil).

A fonte Figtree é empacotada no app (declarada no `pubspec.yaml`): funciona offline e mantém os testes determinísticos.

## Rotas

A abertura do app aponta para `/login`, com o mock da tela Entrar baseado nos exports do Figma. Usa os temas existentes e funciona sem backend. O formulário valida o `LoginRequest` da US-06: e-mail de até 254 caracteres e senha de 1 a 72; normaliza o e-mail para minúsculas e preserva a senha.

O `loginGatewayProvider` fornece um `StubLoginGateway`: após um breve carregamento, simula `501 NOT_IMPLEMENTED` da US-14 e mostra um aviso, sem criar sessão ou armazenar credenciais. Para testar, use `maria.souza@exemplo.com` e `senha-forte-123`; campos inválidos mostram mensagens individuais. A recuperação de senha orienta procurar a administração, pois não há endpoint no contrato v1. A futura integração HTTP deve substituir esse gateway por `POST /api/v1/auth/login` e tratar a resposta de autenticação.

Enquanto o login não existe, o botão **Entrar em modo demonstração** abre a Home (`/`) sem autenticar e sem criar sessão — serve apenas para percorrer o fluxo da US-10.

Declaradas em `lib/core/router/app_router.dart`. Para uma tela nova: crie a página em `lib/features/<feature>/`, adicione o caminho em `AppRoutes` e um `GoRoute` na lista. Redirects (ex.: exigir login) entram no próprio `GoRouter`, lendo providers via `ref`.

## Scanner de QR (`/scan`, US-10)

A Home leva ao scanner. A tela pede a permissão de localização, abre a câmera com `mobile_scanner` e, ao ler um QR, mostra o valor lido e a latitude/longitude obtidas com `geolocator`. **Ela não libera acesso nem chama o backend**: a liberação é a US-29.

- **Estados**: permissão pendente, permissão negada (com nova tentativa), escaneando, lendo posição, sucesso e erro — cada um com mensagem própria em `FeedbackBanner` (`successSoft`/`errorSoft`, texto `onSoft`, contraste AA nos dois temas).
- **Portas de teste**: `QrScannerGateway` (preview da câmera) e `LocationGateway` (permissão e posição) em `scanner_contracts.dart`; `scanner_gateways.dart` traz os adaptadores reais (`MobileScannerGateway`, `GeolocatorLocationGateway`) e os providers `qrScannerGatewayProvider`/`locationGatewayProvider`, sobrescritos nos testes por fakes.
- **Localização**: `MaterialApp.router` roda em `pt`, com `GlobalMaterialLocalizations`, então os textos do Material (voltar, cancelar, permissões) saem em português. Coordenadas seguem o formato pt-BR (`-23,550520`).
- **Permissões**: `AndroidManifest.xml` declara `CAMERA`, `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`. O projeto ainda não tem alvo iOS; quando o tiver, `Info.plist` precisa de `NSCameraUsageDescription` e `NSLocationWhenInUseUsageDescription`.

