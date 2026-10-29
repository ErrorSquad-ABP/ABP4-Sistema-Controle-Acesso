import 'package:controle_acesso/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/auth/fakes.dart';

void main() {
  testWidgets('app roda em português do Brasil', (tester) async {
    await tester.pumpWidget(
      ProviderScope(overrides: authOverrides(), child: const App()),
    );
    await tester.pumpAndSettle();

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(app.locale, const Locale('pt', 'BR'));
    expect(app.supportedLocales, [const Locale('pt', 'BR')]);
    expect(app.localizationsDelegates, isNotNull);

    final context = tester.element(find.byType(Scaffold));
    expect(MaterialLocalizations.of(context).cancelButtonLabel, 'Cancelar');
    expect(MaterialLocalizations.of(context).backButtonTooltip, 'Voltar');
  });
}
