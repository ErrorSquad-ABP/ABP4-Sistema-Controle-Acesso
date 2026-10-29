import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

const _oneSecond = Duration(seconds: 1);

void main() {
  Future<void> pumpApp(
    WidgetTester tester,
    InMemorySessionStore store, {
    FakeAuthGateway? gateway,
    FakeClock? clock,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store, gateway: gateway, clock: clock),
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  String emailField(WidgetTester tester) => tester
      .widget<TextFormField>(find.byType(TextFormField).first)
      .controller!
      .text;

  testWidgets('mostra a abertura enquanto restaura a sessão', (tester) async {
    final store = InMemorySessionStore(sessionFor())
      ..readGate = Completer<void>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store),
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.text('Verificando sua sessão…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    store.readGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
  });

  testWidgets('sessão salva abre direto na Home', (tester) async {
    await pumpApp(tester, InMemorySessionStore(sessionFor()));

    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsNothing);
  });

  testWidgets('sair da conta pede confirmação e volta ao login sem aviso', (
    tester,
  ) async {
    final store = InMemorySessionStore(sessionFor());
    await pumpApp(tester, store);

    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(store.session, isNotNull);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.textContaining('Sua sessão'), findsNothing);
    expect(emailField(tester), isEmpty);
  });

  testWidgets('Keystore que recusa apagar avisa com erro no login', (
    tester,
  ) async {
    final store = InMemorySessionStore(sessionFor())..failClear = true;
    await pumpApp(tester, store);

    await tester.ensureVisible(find.text('Sair da conta'));
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.textContaining('não confirmou a exclusão'), findsOneWidget);
    final banner = tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));
    expect(banner.tone, FeedbackTone.error);
    expect(emailField(tester), 'maria.souza@exemplo.com');
  });

  testWidgets('token vencido com o app aberto volta ao login com aviso', (
    tester,
  ) async {
    final store = InMemorySessionStore(
      sessionFor(validFor: const Duration(minutes: 5)),
    );
    await pumpApp(tester, store);
    expect(find.text('Olá, Maria'), findsOneWidget);

    // O timer usa a mesma folga do isExpiredAt: sai 30 s antes do vencimento.
    const expiresIn = Duration(minutes: 5);
    await tester.pump(expiresIn - AuthSession.expirySkew - _oneSecond);
    expect(find.text('Olá, Maria'), findsOneWidget);
    await tester.pump(_oneSecond);
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
    expect(emailField(tester), 'maria.souza@exemplo.com');
  });

  testWidgets('voltar do segundo plano com o token vencido leva ao login', (
    tester,
  ) async {
    final clock = FakeClock();
    await pumpApp(tester, InMemorySessionStore(sessionFor()), clock: clock);

    clock.advance(const Duration(hours: 2));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();

    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
  });

  testWidgets('voltar do segundo plano reagenda a saída pelo relógio real', (
    tester,
  ) async {
    final clock = FakeClock();
    await pumpApp(tester, InMemorySessionStore(sessionFor()), clock: clock);

    // Aparelho suspenso por 50 min: o relógio anda, o timer não.
    clock.advance(const Duration(minutes: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('Olá, Maria'), findsOneWidget);

    // Restam 10 min de token: a saída vem 30 s antes, não no prazo antigo.
    const remaining = Duration(minutes: 10);
    await tester.pump(remaining - AuthSession.expirySkew - _oneSecond);
    expect(find.text('Olá, Maria'), findsOneWidget);
    await tester.pump(_oneSecond);
    await tester.pumpAndSettle();

    expect(find.text('Sua sessão expirou. Entre novamente.'), findsOneWidget);
  });

  testWidgets('sessão recusada na abertura avisa e o aviso some ao tentar', (
    tester,
  ) async {
    final gateway = FakeAuthGateway(meFailure: AuthFailureReason.unauthorized);
    await pumpApp(tester, InMemorySessionStore(sessionFor()), gateway: gateway);

    expect(
      find.text('Sua sessão foi encerrada. Entre novamente.'),
      findsOneWidget,
    );
    expect(emailField(tester), 'maria.souza@exemplo.com');

    gateway.loginFailure = AuthFailureReason.unauthorized;
    await tester.enterText(find.byType(TextFormField).last, 'senha-errada');
    await tester.ensureVisible(find.text('Entrar'));
    await tester.tap(find.text('Entrar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Sua sessão'), findsNothing);
    expect(find.textContaining('E-mail ou senha incorretos'), findsOneWidget);
  });
}
