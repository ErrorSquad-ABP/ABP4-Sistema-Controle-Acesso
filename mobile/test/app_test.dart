import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/theme_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'features/auth/fakes.dart';

void main() {
  Color scaffoldBackground(WidgetTester tester) {
    final context = tester.element(find.byType(Scaffold));
    return Theme.of(context).scaffoldBackgroundColor;
  }

  testWidgets('sem sessão abre no login com o tema claro', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: authOverrides(), child: const App()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
    expect(find.text('CONTROLE DE ACESSO'), findsOneWidget);
    expect(scaffoldBackground(tester), AppPalette.light.background);
  });

  testWidgets('troca para o tema escuro pelo themeModeProvider', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(overrides: authOverrides(), child: const App()),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(App)),
    );
    container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(scaffoldBackground(tester), AppPalette.dark.background);
  });
}
