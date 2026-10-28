import 'package:controle_acesso/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fakes.dart';

void main() {
  // RNF04 (público idoso): telas não podem estourar com a fonte do sistema
  // ampliada num aparelho pequeno.
  for (final (name, store) in [
    ('login', () => InMemorySessionStore()),
    ('Home', () => InMemorySessionStore(sessionFor())),
  ]) {
    testWidgets('$name não estoura com fonte 2x em 360x640', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await tester.pumpWidget(
        ProviderScope(
          overrides: authOverrides(store: store()),
          child: const App(),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  }
}
