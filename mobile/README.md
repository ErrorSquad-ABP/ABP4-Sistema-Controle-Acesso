# mobile

App Flutter do usuário e da administração — Flutter 3.47 (Dart 3.13) + Riverpod 3 + go_router, alvo Android (US-09).

## Estrutura

```text
lib/
├─ main.dart                 ProviderScope + runApp
├─ app.dart                  MaterialApp.router: temas, themeMode, pt-BR e router via Riverpod
├─ core/
│  ├─ clock.dart             relógio injetável (clockProvider)
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
| `flutter test` | testes do app, do tema, do login/sessão e do scanner |
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

O app abre em `/loading` (estado "carregando" do Figma) enquanto restaura a sessão salva e depois segue para a Home (logado) ou para `/login`.

- **Login**: tela Entrar do Figma (inclusive o rodapé "ERRORSQUAD · FATEC"). O formulário valida o `LoginRequest` da US-06 (e-mail de até 254 caracteres, sem os espaços das pontas e normalizado para minúsculas; senha de 1 a 72, preservada) e chama `POST /api/v1/auth/login` (`HttpAuthGateway`). Cada falha tem mensagem própria em `FeedbackBanner`: credencial recusada ou conta desativada (401), entrada recusada (400), muitas tentativas (429), serviço fora do ar (5xx), sem conexão ("Sem conexão com o servidor…"), tempo esgotado ("O servidor demorou para responder…") e resposta fora do contrato. A recuperação de senha orienta procurar a administração, pois não há endpoint no contrato v1.
- **Sessão**: `SessionController` (`sessionControllerProvider`) mantém um `SessionState`: a `AuthSession` ativa (JWT, vencimento calculado de `expiresIn` e usuário) ou, deslogado, o motivo de a sessão anterior ter acabado. `currentSessionProvider` expõe só a sessão ativa. `SecureSessionStore` persiste em `flutter_secure_storage` (Keystore no Android); a senha nunca é gravada e valor corrompido ou estruturalmente inválido (token vazio, vencimento ilegível, usuário sem nome/e-mail/perfil) é descartado. Se o Keystore falhar ao gravar, o login vale só em memória. Na saída, o cofre é invalidado em duas fases: primeiro a chave recebe um valor que a leitura descarta, depois o `delete`; se nem gravar nem apagar funcionar, tenta `deleteAll` e, no limite, avisa com erro no login — a saída do app acontece mesmo assim.
- **Restauração**: sessão vencida é apagada sem chamar o backend. Sessão válida abre na hora, sem esperar a rede, e é conferida em segundo plano em `GET /auth/me`: um 401 encerra a sessão com o aviso de sessão encerrada; sem rede, com TLS recusado (Wi-Fi com portal cativo) ou com o backend fora, ela vale até vencer. A resposta atualiza o usuário salvo.
- **Expiração**: um timer encerra a sessão quando o token vence (com 30 s de folga), e a volta do app do segundo plano confere de novo (o timer não conta o tempo com o aparelho suspenso).
- **Aviso no login**: sessão vencida mostra "Sua sessão expirou. Entre novamente."; recusada pelo backend, "Sua sessão foi encerrada. Entre novamente."; e, se o cofre não confirmou a exclusão, o aviso em tom de erro "…o aparelho não confirmou a exclusão. Se o app abrir conectado, saia novamente.". O e-mail vem preenchido e o aviso some na próxima tentativa. A saída pedida pelo usuário não gera aviso.
- **Saída**: o botão "Sair da conta" fica provisoriamente na Home, com confirmação; no Figma ele mora no Perfil, que entra com o shell da US-28. O JWT é stateless, então não há chamada de logout no backend.
- **Rotas protegidas das próximas telas** (US-28, US-29, admin): use `authenticatedClientProvider` no lugar do `httpClientProvider`. Ele põe o `Authorization: Bearer` da sessão **só quando a URL é da origem do `API_BASE_URL`** (mesmo esquema, host e porta) e, numa resposta 401, encerra a sessão com o aviso de sessão encerrada; sem sessão, lança `AuthFailure(unauthorized)` sem fazer a requisição.
- **Android**: `allowBackup="false"` e `data_extraction_rules.xml` tiram a sessão do backup e da transferência entre aparelhos (a chave do Keystore não vai junto).
- **Testes**: `test/features/auth/fakes.dart` traz `FakeAuthGateway`, `InMemorySessionStore` (com falhas simuladas do Keystore), `FakeClock` e `authOverrides()`; a porta `SessionVault` (`session_store.dart`) deixa o teste do `SecureSessionStore` simular o cofre que falha ao gravar ou apagar. Todo teste que monta o `App` precisa desses overrides, porque o `flutter_secure_storage` real não responde no `flutter test`.

## Rotas

Declaradas em `lib/core/router/app_router.dart`. Para uma tela nova: crie a página em `lib/features/<feature>/`, adicione o caminho em `AppRoutes` e um `GoRoute` na lista. O `sessionRedirect` protege toda rota que não seja `/login` ou `/loading`: deslogado vai ao login, logado sai das telas públicas. O router não é recriado quando a sessão muda: o `refreshListenable` reavalia o redirect.

O antigo **modo demonstração** (Home sem autenticar) saiu com o login real.

## Scanner de QR (`/scan`, US-10)

A Home (logado) leva ao scanner. A tela pede a permissão de localização, abre a câmera com `mobile_scanner` e, ao ler um QR, mostra o valor lido e a latitude/longitude obtidas com `geolocator`. **Ela não libera acesso nem chama o backend**: a liberação é a US-29.

- **Estados**: permissão pendente, permissão negada (com nova tentativa), escaneando, lendo posição, sucesso e erro — cada um com mensagem própria em `FeedbackBanner` (`successSoft`/`errorSoft`, texto `onSoft`, contraste AA nos dois temas).
- **Portas de teste**: `QrScannerGateway` (preview da câmera) e `LocationGateway` (permissão e posição) em `scanner_contracts.dart`; `scanner_gateways.dart` traz os adaptadores reais (`MobileScannerGateway`, `GeolocatorLocationGateway`) e os providers `qrScannerGatewayProvider`/`locationGatewayProvider`, sobrescritos nos testes por fakes.
- **Localização**: `MaterialApp.router` roda em `pt`, com `GlobalMaterialLocalizations`, então os textos do Material (voltar, cancelar, permissões) saem em português. Coordenadas seguem o formato pt-BR (`-23,550520`).
- **Permissões**: `AndroidManifest.xml` declara `CAMERA`, `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`. O projeto ainda não tem alvo iOS; quando o tiver, `Info.plist` precisa de `NSCameraUsageDescription` e `NSLocationWhenInUseUsageDescription`.

