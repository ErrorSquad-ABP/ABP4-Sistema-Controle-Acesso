import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fakes.dart';

void main() {
  // RNF04 (público idoso): telas não podem estourar com a fonte do sistema
  // ampliada num aparelho pequeno.
  void useSmallPhone(WidgetTester tester) {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
  }

  Future<void> pumpApp(WidgetTester tester, InMemorySessionStore store) =>
      tester.pumpWidget(
        ProviderScope(
          overrides: authOverrides(store: store),
          child: const App(),
        ),
      );

  for (final (name, store) in [
    ('login', () => InMemorySessionStore()),
    ('Home', () => InMemorySessionStore(sessionFor())),
  ]) {
    testWidgets('$name não estoura com fonte 2x em 360x640', (tester) async {
      useSmallPhone(tester);
      await pumpApp(tester, store());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('carregamento não estoura com fonte 2x em 360x640', (
    tester,
  ) async {
    useSmallPhone(tester);
    // Sessão salva com leitura presa: o app fica na tela de abertura.
    final store = InMemorySessionStore(sessionFor())
      ..readGate = Completer<void>();
    await pumpApp(tester, store);
    // O indicador gira para sempre: `pumpAndSettle` não terminaria.
    await tester.pump();

    expect(find.text('Verificando sua sessão…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
