import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/app_spacing.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/auth/state_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester,
    Widget card, {
    bool dark = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.screen),
              child: card,
            ),
          ),
        ),
      ),
    );
    // MaterialApp anima a troca de tema (200 ms); o indicador gira para sempre,
    // entao avancar o tempo no lugar de usar pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  BoxDecoration cardDecoration(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(StateCard),
            matching: find.byType(Container),
          )
          .first,
    );
    return container.decoration! as BoxDecoration;
  }

  testWidgets('carregando mostra o indicador e a frase do frame', (
    tester,
  ) async {
    await pump(tester, const StateCard.loading());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Carregando suas autorizações…'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vazio mostra o icone, o titulo e a explicacao do frame', (
    tester,
  ) async {
    await pump(tester, const StateCard.empty());

    expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
    expect(find.text('Nenhuma autorização ainda'), findsOneWidget);
    expect(
      find.text('Suas liberações aparecerão aqui assim que forem criadas.'),
      findsOneWidget,
    );
  });

  testWidgets('erro oferece tentar de novo e chama o callback', (tester) async {
    var retries = 0;
    await pump(tester, StateCard.error(onRetry: () => retries++));

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.text('Não foi possível carregar'), findsOneWidget);
    await tester.tap(find.text('Tentar novamente'));
    expect(retries, 1);
  });

  testWidgets('cartao usa superficie e hairline nos dois temas', (
    tester,
  ) async {
    for (final (dark, palette) in [
      (false, AppPalette.light),
      (true, AppPalette.dark),
    ]) {
      await pump(tester, const StateCard.empty(), dark: dark);
      final decoration = cardDecoration(tester);

      expect(decoration.color, palette.surface);
      expect(
        (decoration.border! as Border).top.color,
        palette.hairline,
        reason: dark ? 'escuro' : 'claro',
      );
      expect(decoration.borderRadius, BorderRadius.circular(AppRadius.card));
    }
  });
}
