import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/app_spacing.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  const message = 'QR lido e posição registrada.';

  Future<void> pumpBanner(
    WidgetTester tester,
    ThemeData theme,
    FeedbackTone tone,
  ) {
    return tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: Scaffold(
          body: FeedbackBanner(tone: tone, message: message),
        ),
      ),
    );
  }

  Color softColor(WidgetTester tester) {
    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FeedbackBanner),
            matching: find.byType(Container),
          )
          .first,
    );
    return (container.decoration! as BoxDecoration).color!;
  }

  testWidgets('sucesso usa successSoft e texto onSoft nos dois temas', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpBanner(tester, theme, FeedbackTone.success);

      final palette = theme.extension<AppPalette>()!;
      expect(softColor(tester), palette.successSoft);
      expect(
        tester.widget<Text>(find.text(message)).style!.color,
        palette.onSoft,
      );
      expect(
        _contrast(palette.successSoft, palette.onSoft),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('erro usa errorSoft e texto onSoft nos dois temas', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      await pumpBanner(tester, theme, FeedbackTone.error);

      final palette = theme.extension<AppPalette>()!;
      expect(softColor(tester), palette.errorSoft);
      expect(
        tester.widget<Text>(find.text(message)).style!.color,
        palette.onSoft,
      );
      expect(
        _contrast(palette.errorSoft, palette.onSoft),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('ícone acompanha o texto e passa AA nos dois temas', (
    tester,
  ) async {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      for (final tone in FeedbackTone.values) {
        await pumpBanner(tester, theme, tone);

        final palette = theme.extension<AppPalette>()!;
        final soft = switch (tone) {
          FeedbackTone.success => palette.successSoft,
          FeedbackTone.error => palette.errorSoft,
          FeedbackTone.warning => palette.warningSoft,
        };
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.color, palette.onSoft);
        expect(_contrast(palette.onSoft, soft), greaterThanOrEqualTo(4.5));
      }
    }
  });

  testWidgets('anuncia a mensagem como região viva', (tester) async {
    await pumpBanner(tester, AppTheme.light(), FeedbackTone.error);

    final semantics = tester.ensureSemantics();
    await tester.pump();
    expect(
      tester.getSemantics(find.byType(FeedbackBanner)),
      matchesSemantics(label: message, isLiveRegion: true),
    );
    semantics.dispose();
  });

  testWidgets('respeita o espaçamento do design system', (tester) async {
    await pumpBanner(tester, AppTheme.light(), FeedbackTone.success);

    final container = tester.widget<Container>(
      find
          .descendant(
            of: find.byType(FeedbackBanner),
            matching: find.byType(Container),
          )
          .first,
    );
    expect(container.padding, const EdgeInsets.all(AppSpacing.sm));
  });
}
