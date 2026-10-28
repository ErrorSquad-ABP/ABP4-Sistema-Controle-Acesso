import 'dart:async';

import 'package:controle_acesso/app.dart';
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
    expect(LoginValidation.password(''), isNotNull);
    expect(LoginValidation.password('a'), isNull);
    expect(LoginValidation.password('a' * 72), isNull);
    expect(LoginValidation.password('a' * 73), isNotNull);
    expect(
      LoginRequest(email: 'Maria@exemplo.com', password: ' senha ').toJson(),
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

  testWidgets('credencial recusada mostra erro e continua no login', (
    tester,
  ) async {
    final store = InMemorySessionStore();
    await pumpApp(
      tester,
      gateway: FakeAuthGateway(loginFailure: AuthFailureReason.unauthorized),
      store: store,
    );

    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('E-mail ou senha incorretos'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(store.session, isNull);
  });

  testWidgets('sem conexão orienta verificar a internet', (tester) async {
    await pumpApp(
      tester,
      gateway: FakeAuthGateway(loginFailure: AuthFailureReason.network),
    );

    await submit(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
  });
}
