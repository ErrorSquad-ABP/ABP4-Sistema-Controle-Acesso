import 'dart:async';

import 'package:controle_acesso/app.dart';
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

  testWidgets('login válido carrega, salva a sessão e abre a Home', (
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
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.text('Condômino · maria.souza@exemplo.com'), findsOneWidget);
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
}
