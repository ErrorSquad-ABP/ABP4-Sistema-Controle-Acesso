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
│  ├─ network/api.dart       endereço do backend (API_BASE_URL) + cliente HTTP
│  └─ router/app_router.dart rotas (AppRoutes), guarda de sessão + appRouterProvider
└─ features/                 uma pasta por feature (auth, scanner, authorizations, admin…)
   ├─ auth/                  login real + sessão persistida (US-27)
   ├─ home/                  tela inicial com o usuário logado e "Sair"
   └─ scanner/               leitura de QR + posição (US-10)
test/                        widget tests do app, do tema, do login, da sessão e do scanner
assets/fonts/figtree/        Figtree 400/500/600/700 + OFL.txt
```

## Rodando

```bash
cd mobile
flutter pub get
flutter run               # emulador/aparelho Android, contra o backend de produção
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:3000   # backend local no emulador
```

Sem `API_BASE_URL`, o app usa o backend de produção (`https://abp-4-sistema-controle-acesso.vercel.app`). No emulador Android, `10.0.2.2` é o `localhost` da máquina; num aparelho físico use `adb reverse tcp:3000 tcp:3000` e `http://localhost:3000`. O `http` em texto claro só é liberado no build de debug (`android/app/src/debug/AndroidManifest.xml`). Para entrar no backend local use as contas da seed de demonstração ([`docs/guides/como-rodar.md`](../docs/guides/como-rodar.md)).

`flutter run -d chrome` abre a tela, mas o login falha no navegador: o backend ainda não responde CORS. O alvo do app é Android.

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

## Login e sessão (US-27)

O app abre em `/carregando` enquanto restaura a sessão salva e depois segue para a Home (logado) ou para `/login`.

- **Login**: o formulário valida o `LoginRequest` da US-06 (e-mail de até 254 caracteres, normalizado para minúsculas; senha de 1 a 72, preservada) e chama `POST /api/v1/auth/login` (`HttpAuthGateway`). Cada falha tem mensagem própria em `FeedbackBanner`: credencial recusada ou conta desativada (401), entrada recusada (400), muitas tentativas (429), serviço fora do ar (5xx), sem conexão/tempo esgotado e resposta fora do contrato. A recuperação de senha orienta procurar a administração, pois não há endpoint no contrato v1.
- **Sessão**: `SessionController` (`sessionControllerProvider`) guarda `AuthSession` (JWT, vencimento calculado de `expiresIn` e usuário). `SecureSessionStore` persiste em `flutter_secure_storage` (Keystore no Android); a senha nunca é gravada. Valor corrompido é descartado e pede novo login.
- **Restauração**: sessão vencida é apagada sem chamar o backend; válida é conferida em `GET /auth/me` (401 apaga a sessão; sem rede mantém até vencer) e atualiza o usuário salvo.
- **Expiração e saída**: um timer encerra a sessão quando o token vence (com 30 s de folga) e o router volta ao login. "Sair", na Home, pede confirmação e apaga a sessão local; o JWT é stateless, então não há chamada de logout no backend.
- **Para as próximas telas** (US-28/US-29): leia o token em `ref.read(sessionControllerProvider).value?.accessToken`; numa resposta 401, chame `ref.read(sessionControllerProvider.notifier).logout()`.
- **Testes**: `test/features/auth/fakes.dart` traz `FakeAuthGateway`, `InMemorySessionStore` e `authOverrides()`; todo teste que monta o `App` precisa desses overrides (o `flutter_secure_storage` real não responde no `flutter test`).

## Rotas

Declaradas em `lib/core/router/app_router.dart`. Para uma tela nova: crie a página em `lib/features/<feature>/`, adicione o caminho em `AppRoutes` e um `GoRoute` na lista. O `sessionRedirect` protege toda rota que não seja `/login` ou `/carregando`: deslogado vai ao login, logado sai das telas públicas. O router não é recriado quando a sessão muda: o `refreshListenable` reavalia o redirect.

O antigo **modo demonstração** (Home sem autenticar) saiu com o login real.

## Scanner de QR (`/scan`, US-10)

A Home (logado) leva ao scanner. A tela pede a permissão de localização, abre a câmera com `mobile_scanner` e, ao ler um QR, mostra o valor lido e a latitude/longitude obtidas com `geolocator`. **Ela não libera acesso nem chama o backend**: a liberação é a US-29.

- **Estados**: permissão pendente, permissão negada (com nova tentativa), escaneando, lendo posição, sucesso e erro — cada um com mensagem própria em `FeedbackBanner` (`successSoft`/`errorSoft`, texto `onSoft`, contraste AA nos dois temas).
- **Portas de teste**: `QrScannerGateway` (preview da câmera) e `LocationGateway` (permissão e posição) em `scanner_contracts.dart`; `scanner_gateways.dart` traz os adaptadores reais (`MobileScannerGateway`, `GeolocatorLocationGateway`) e os providers `qrScannerGatewayProvider`/`locationGatewayProvider`, sobrescritos nos testes por fakes.
- **Localização**: `MaterialApp.router` roda em `pt`, com `GlobalMaterialLocalizations`, então os textos do Material (voltar, cancelar, permissões) saem em português. Coordenadas seguem o formato pt-BR (`-23,550520`).
- **Permissões**: `AndroidManifest.xml` declara `CAMERA`, `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`. O projeto ainda não tem alvo iOS; quando o tiver, `Info.plist` precisa de `NSCameraUsageDescription` e `NSLocationWhenInUseUsageDescription`.

