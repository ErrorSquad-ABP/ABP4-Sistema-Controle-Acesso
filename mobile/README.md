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

`flutter run -d chrome` precisa que o backend libere a origem do navegador (CORS, DT-08). Com o backend local rodando com `CORS_ALLOWED_ORIGINS=http://localhost:5000`, use `flutter run -d chrome --web-port 5000 --dart-define=API_BASE_URL=http://localhost:3000`. O backend de produção só aceita as origens da allowlist dele. O alvo do app é Android, onde CORS não se aplica ([`docs/api/README.md`](../docs/api/README.md#cors)).

| Comando | O que faz |
|---|---|
| `flutter analyze` | lints (`flutter_lints` + regras extras em `analysis_options.yaml`) |
| `flutter test` | testes do app, do tema, do login/sessão e do scanner |
| `dart format lib test` | formatação |
| `flutter build apk --release` | APK Android (exige Android SDK e JDK 17) |
| `flutter build web` | build web |

O CI (`ci-mobile.yml`) roda em todo PR: `ci-mobile-check` (`flutter pub get`, `flutter analyze`, `flutter test`), `ci-mobile-build-android` e `ci-mobile-install-android`.

## APK Android no CI (DT-10)

`ci-mobile-build-android` gera `flutter build apk --release` e **falha se o Gradle ou o empacotamento quebrar**. Em seguida `tool/ci/verify_apk.sh` confere, com `apksigner` e `aapt`, a assinatura e a identidade do signatário (precisa ser a chave debug, `CN=Android Debug`), o pacote `br.fatec.errorsquad.controle_acesso`, a activity de entrada, as permissões de câmera/localização/internet e a presença de binários `arm64-v8a`. O APK sai como artefato **`controle-acesso-apk`** (`controle-acesso-<sha7>.apk`, retido por 14 dias) na página da execução do workflow.

`ci-mobile-install-android` baixa esse artefato e roda `tool/ci/android_install_smoke.sh` no **aparelho de referência do CI**: emulador Pixel 6, Android 14 (API 34, x86_64). O script instala o APK, abre o app e falha se ele não instalar, não subir, não ficar em primeiro plano (activity principal com foco) ou cair nos primeiros segundos. Não exige backend.

Para repetir num aparelho físico (com depuração USB):

```bash
# baixe o artefato `controle-acesso-apk` da execução do workflow, depois:
adb install -r controle-acesso-<sha7>.apk
bash tool/ci/android_install_smoke.sh controle-acesso-<sha7>.apk
```

Limites:

- O release ainda é assinado com a chave **debug** (`app/build.gradle.kts`): instala em aparelho, mas não serve para loja. Não há AAB; ele depende de um keystore de release, que deve entrar como secret do repositório antes da publicação.
- A chave debug muda entre execuções, então instalar por cima de uma build anterior falha com `INSTALL_FAILED_UPDATE_INCOMPATIBLE`: rode `adb uninstall br.fatec.errorsquad.controle_acesso` antes.
- O emulador comprova instalação e abertura, não câmera nem GPS reais. A validação em aparelho físico segue na **DT-12**.

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
- **Rotas protegidas das próximas telas** (US-28, admin; o scanner da US-29 já usa): use `authenticatedClientProvider` no lugar do `httpClientProvider`. Ele põe o `Authorization: Bearer` da sessão **só quando a URL é da origem do `API_BASE_URL`** (mesmo esquema, host e porta) e, numa resposta 401, encerra a sessão com o aviso de sessão encerrada; sem sessão, lança `AuthFailure(unauthorized)` sem fazer a requisição.
- **Android**: `allowBackup="false"` e `data_extraction_rules.xml` tiram a sessão do backup e da transferência entre aparelhos (a chave do Keystore não vai junto).
- **Testes**: `test/features/auth/fakes.dart` traz `FakeAuthGateway`, `InMemorySessionStore` (com falhas simuladas do Keystore), `FakeClock` e `authOverrides()`; a porta `SessionVault` (`session_store.dart`) deixa o teste do `SecureSessionStore` simular o cofre que falha ao gravar ou apagar. Todo teste que monta o `App` precisa desses overrides, porque o `flutter_secure_storage` real não responde no `flutter test`.

## Rotas

Declaradas em `lib/core/router/app_router.dart`. Para uma tela nova: crie a página em `lib/features/<feature>/`, adicione o caminho em `AppRoutes` e um `GoRoute` na lista. O `sessionRedirect` protege toda rota que não seja `/login` ou `/loading`: deslogado vai ao login, logado sai das telas públicas. O router não é recriado quando a sessão muda: o `refreshListenable` reavalia o redirect.

O antigo **modo demonstração** (Home sem autenticar) saiu com o login real.

## Scanner de QR e pedido de acesso (`/scan`, US-10 e US-29)

A Home (logado) leva ao scanner. A tela pede a permissão de localização, abre a câmera com `mobile_scanner`, lê o QR do terminal, obtém a posição com `geolocator` e **pede o acesso ao backend** (`POST /api/v1/access-events/qr`, US-20). O resultado ocupa a tela inteira, como no Figma: **Acesso liberado** (local, hora e botão Concluir) ou **Acesso negado** (motivo em linguagem simples, orientação e os botões Escanear de novo e Voltar ao início).

- **Fluxo** (`ScannerController`): permissão → escaneando → lendo posição → enviando → resultado. Depois da primeira leitura o controller ignora as detecções repetidas do preview (o `mobile_scanner` repete a cada ~250 ms enquanto o QR está à vista), então uma leitura gera um único pedido. O valor do QR é uma credencial de 10 s: não fica no estado nem aparece em nenhuma tela.
- **QR do terminal**: o formato é `v1.<terminalId>.<iat>.<exp>.<assinatura>` (US-19). O app só lê o `terminalId` do token (`terminalIdFromQrToken`) para montar o pedido; autenticidade, validade e a conferência do terminal são do backend. Um QR fora desse formato é recusado no aparelho ("Este não é o QR de um terminal"), sem ler a posição nem chamar a API.
- **Posição**: vai no pedido com a precisão do GPS (`accuracyMeters`) quando o aparelho informa. Não há posição em cache: a geofence do backend é de 100 m e uma posição antiga poderia liberar quem já saiu.
- **Idempotência**: cada tentativa gera um `requestId` (UUID v4). Se o envio falha por rede, tempo esgotado, 429 ou 5xx, "Tentar novamente" reenvia o **mesmo** pedido com o mesmo `requestId`, e o backend não consome a autorização duas vezes. "Escanear de novo" gera outro.
- **Negar não é erro**: o backend responde `200` com `decision: DENIED` e o motivo. O texto da tela vem do motivo (`access_messages.dart`, os 11 motivos do contrato mais um genérico), porque o `message` do backend é técnico (`Acesso negado: OUT_OF_RANGE`).
- **Falhas de envio** (`HttpAccessGateway`, mesma ideia do `HttpAuthGateway`): 401 (a sessão é encerrada pelo `AuthenticatedClient`), 400, 429, 5xx, sem conexão, tempo esgotado e resposta fora do contrato têm mensagem própria; 400 e 401 só oferecem escanear de novo.
- **QR de 10 s e GPS lento**: se a posição demorar e o token vencer, o backend nega com "QR expirado" e a tela orienta a apontar para o QR atualizado.
- **Estados**: permissão pendente, permissão negada (com nova tentativa), escaneando, lendo posição, enviando, resultado e erro — cada um com mensagem própria em `FeedbackBanner` (`successSoft`/`errorSoft`, texto `onSoft`, contraste AA nos dois temas). A tela de leitura rola com a fonte do sistema ampliada (RNF04).
- **Portas de teste**: `QrScannerGateway` (preview da câmera), `LocationGateway` (permissão e posição) e `AccessGateway` (pedido de acesso, `access_contract.dart`); `scanner_gateways.dart` e `http_access_gateway.dart` trazem os adaptadores reais e os providers `qrScannerGatewayProvider`, `locationGatewayProvider` e `accessGatewayProvider`, sobrescritos nos testes por fakes (`test/features/scanner/fakes.dart`, com `FakeAccessGateway` e `FakeRequestIds`).
- **Localização**: `MaterialApp.router` roda em `pt`, com `GlobalMaterialLocalizations`, então os textos do Material (voltar, cancelar, permissões) saem em português. Coordenadas seguem o formato pt-BR (`-23,550520`).
- **Permissões**: `AndroidManifest.xml` declara `CAMERA`, `ACCESS_FINE_LOCATION` e `ACCESS_COARSE_LOCATION`. O projeto ainda não tem alvo iOS; quando o tiver, `Info.plist` precisa de `NSCameraUsageDescription` e `NSLocationWhenInUseUsageDescription`.

