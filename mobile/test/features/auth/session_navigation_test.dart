import 'package:controle_acesso/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, InMemorySessionStore store) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: authOverrides(store: store),
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('sessão salva abre direto na Home', (tester) async {
    await pumpApp(tester, InMemorySessionStore(sessionFor()));

    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(find.text('Bem-vindo de volta'), findsNothing);
  });

  testWidgets('sair pede confirmação, apaga a sessão e volta ao login', (
    tester,
  ) async {
    final store = InMemorySessionStore(sessionFor());
    await pumpApp(tester, store);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(find.text('Olá, Maria'), findsOneWidget);
    expect(store.session, isNotNull);

    await tester.tap(find.byTooltip('Sair'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });

  testWidgets('token vencido com o app aberto volta ao login', (tester) async {
    final store = InMemorySessionStore(
      sessionFor(validFor: const Duration(minutes: 5)),
    );
    await pumpApp(tester, store);
    expect(find.text('Olá, Maria'), findsOneWidget);

    await tester.pump(const Duration(minutes: 5));
    await tester.pumpAndSettle();

    expect(store.session, isNull);
    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });
}
