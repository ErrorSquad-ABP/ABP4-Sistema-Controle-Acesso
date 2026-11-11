import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/app_spacing.dart';
import 'package:controle_acesso/core/theme/theme_mode_provider.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    FakeAuthGateway? gateway,
    InMemorySessionStore? store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(gateway: gateway, store: store),
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextFormField).first,
      'Maria.Souza@exemplo.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'senha-forte-123');
    await tester.ensureVisible(find.text('Entrar'));
    // A rolagem do ensureVisible vale no quadro seguinte.
    await tester.pump();
    await tester.tap(find.text('Entrar'));
  }

  test('valida os limites do contrato e normaliza somente o e-mail', () {
    expect(LoginValidation.email('invalido'), isNotNull);
    expect(LoginValidation.email('a..b@exemplo.com'), isNotNull);
    expect(LoginValidation.email('Maria@exemplo.com'), isNull);
    expect(LoginValidation.email(' Maria@exemplo.com '), isNull);
    expect(LoginValidation.email('   '), isNotNull);
    expect(LoginValidation.password(''), isNotNull);
    expect(LoginValidation.password('a'), isNull);
    expect(LoginValidation.password('a' * 72), isNull);
    expect(LoginValidation.password('a' * 73), isNotNull);
    expect(
      LoginRequest(email: ' Maria@exemplo.com ', password: ' senha ').toJson(),
      {'email': 'maria@exemplo.com', 'password': ' senha '},
    );
  });

  testWidgets('mostra erros por campo e permite revelar a senha', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Informe sua senha.'), findsOneWidget);
    await tester.ensureVisible(find.byTooltip('Mostrar senha'));
    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
  });

  testWidgets('login válido carrega, salva a sessão e sai do login', (
    tester,
  ) async {
    final gateway = FakeAuthGateway()..loginGate = Completer<void>();
    final store = InMemorySessionStore();
    await pumpApp(tester, gateway: gateway, store: store);

    await submit(tester);
    await tester.pump();
    expect(find.text('Entrando…'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );

    gateway.loginGate!.complete();
    await tester.pumpAndSettle();

    expect(gateway.logins.single.email, 'maria.souza@exemplo.com');
    expect(store.session?.accessToken, 'jwt-maria');
    expect(find.text('Bem-vindo de volta'), findsNothing);
  });

  testWidgets('cada falha do login tem mensagem e tom próprios', (
    tester,
  ) async {
    const cases = {
      AuthFailureReason.unauthorized: (
        'E-mail ou senha incorretos',
        FeedbackTone.error,
      ),
      AuthFailureReason.invalidRequest: (
        'Confira o e-mail e a senha',
        FeedbackTone.error,
      ),
      AuthFailureReason.tooManyRequests: (
        'Muitas tentativas seguidas',
        FeedbackTone.warning,
      ),
      AuthFailureReason.unavailable: (
        'O serviço de acesso está fora do ar',
        FeedbackTone.warning,
      ),
      AuthFailureReason.network: (
        'Sem conexão com o servidor',
        FeedbackTone.warning,
      ),
      AuthFailureReason.timeout: (
        'O servidor demorou para responder',
        FeedbackTone.warning,
      ),
      AuthFailureReason.unexpected: (
        'Não foi possível entrar',
        FeedbackTone.error,
      ),
    };
    final gateway = FakeAuthGateway();
    final store = InMemorySessionStore();
    await pumpApp(tester, gateway: gateway, store: store);

    for (final MapEntry(key: reason, value: (message, tone)) in cases.entries) {
      gateway.loginFailure = reason;
      await submit(tester);
      await tester.pumpAndSettle();

      final banner = tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));
      expect(banner.message, startsWith(message), reason: reason.name);
      expect(banner.tone, tone, reason: reason.name);
      expect(find.text('Bem-vindo de volta'), findsOneWidget);
      expect(store.session, isNull);
    }
  });

  testWidgets('leitor de tela anuncia o rótulo, não o exemplo do campo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpApp(tester);

    String label(Finder field) => tester.getSemantics(field).label;
    expect(label(find.byType(TextField).first), startsWith('E-mail'));
    expect(label(find.byType(TextField).last), startsWith('Senha'));
    semantics.dispose();
  });

  testWidgets('mostra o rodapé do Figma', (tester) async {
    await pumpApp(tester);
    expect(find.text('ERRORSQUAD · FATEC'), findsOneWidget);
  });

  testWidgets('segue o frame Entrar: marca, titulos, acao e rodape', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester);

    expect(find.text('CONTROLE DE ACESSO'), findsOneWidget);
    expect(find.text('ACESSO CORPORATIVO'), findsOneWidget);

    final title = tester.widget<Text>(find.text('Bem-vindo de volta'));
    expect(title.style?.fontSize, 32);
    expect(title.style?.fontWeight, FontWeight.w600);
    expect(title.textAlign, isNot(TextAlign.center));

    // Marca: selo de 64 com o escudo de 32.
    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.verified_user_outlined),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(tile.constraints?.maxWidth, 64);
    expect(tile.constraints?.maxHeight, 64);

    // Ação principal com 56 de altura, rótulo a esquerda e seta a direita.
    expect(
      tester.getSize(find.byType(FilledButton)).height,
      AppSpacing.controlHeight,
    );
    expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);

    // Rodapé preso no fim da tela, 40 acima da borda como no frame.
    expect(
      tester.getBottomLeft(find.text('ERRORSQUAD · FATEC')).dy,
      closeTo(844 - 40, 0.5),
    );
  });

  testWidgets('escuro usa o selo claro, hairline e textos do frame', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(),
          themeModeProvider.overrideWith(_DarkModeNotifier.new),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    final tile = tester.widget<Container>(
      find
          .ancestor(
            of: find.byIcon(Icons.verified_user_outlined),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(
      (tile.decoration! as BoxDecoration).color,
      AppPalette.dark.text,
      reason: 'no escuro o selo e o bloco claro do frame',
    );
    expect(
      tester.widget<Icon>(find.byIcon(Icons.verified_user_outlined)).color,
      AppPalette.dark.background,
    );
    expect(
      tester.widget<Text>(find.text('ACESSO CORPORATIVO')).style?.color,
      AppPalette.dark.textSecondary,
    );
  });
}

class _DarkModeNotifier extends ThemeModeNotifier {
  @override
  ThemeMode build() => ThemeMode.dark;
}
