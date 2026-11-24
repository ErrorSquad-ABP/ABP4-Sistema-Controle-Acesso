import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/core/widgets/web_demo_notice.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(
    WidgetTester tester, {
    required bool isWeb,
    ThemeData? theme,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.light(),
        home: Scaffold(body: WebDemoNotice(isWeb: isWeb)),
      ),
    );
  }

  testWidgets('no navegador declara NFC, câmera, localização e https', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pump(tester, isWeb: true, theme: theme);

      final banner = tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));
      expect(banner.tone, FeedbackTone.warning);
      expect(find.text(WebDemoNotice.message), findsOneWidget);
      expect(WebDemoNotice.message, contains('NFC'));
      expect(WebDemoNotice.message, contains('Câmera e localização'));
      expect(WebDemoNotice.message, contains('https'));
      expect(find.bySemanticsLabel(WebDemoNotice.message), findsOneWidget);
    }
  });

  testWidgets('fora do navegador não mostra nada', (tester) async {
    await pump(tester, isWeb: false);

    expect(find.byType(FeedbackBanner), findsNothing);
    expect(find.textContaining('NFC'), findsNothing);
  });
}
