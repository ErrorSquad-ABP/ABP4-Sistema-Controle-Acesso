import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/app_spacing.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppTheme', () {
    test('claro usa os tokens do design system', () {
      final theme = AppTheme.light();

      expect(theme.brightness, Brightness.light);
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFAFAFA));
      expect(theme.colorScheme.surface, const Color(0xFFFFFFFF));
      expect(theme.colorScheme.onSurface, const Color(0xFF0A0A0A));
      expect(theme.colorScheme.outline, const Color(0xFFE8E8E8));
      expect(theme.extension<AppPalette>(), AppPalette.light);
    });

    test('escuro usa os tokens do design system', () {
      final theme = AppTheme.dark();

      expect(theme.brightness, Brightness.dark);
      expect(theme.scaffoldBackgroundColor, const Color(0xFF0A0A0A));
      expect(theme.colorScheme.surface, const Color(0xFF161616));
      expect(theme.colorScheme.onSurface, const Color(0xFFFAFAFA));
      expect(theme.colorScheme.outline, const Color(0xFF262626));
      expect(theme.extension<AppPalette>(), AppPalette.dark);
    });

    test('feedback de estado e igual nos dois temas', () {
      for (final palette in [AppPalette.light, AppPalette.dark]) {
        expect(palette.success, const Color(0xFF16A34A));
        expect(palette.error, const Color(0xFFDC2626));
        expect(palette.warning, const Color(0xFFD97706));
      }
    });

    test('botao primario e preto no claro e branco no escuro', () {
      Color? primaryBackground(ThemeData theme) => theme
          .filledButtonTheme
          .style
          ?.backgroundColor
          ?.resolve(<WidgetState>{});

      expect(primaryBackground(AppTheme.light()), const Color(0xFF0A0A0A));
      expect(primaryBackground(AppTheme.dark()), const Color(0xFFFAFAFA));
    });

    test('tipografia Figtree com a escala do Figma', () {
      final text = AppTheme.light().textTheme;

      expect(text.bodyLarge?.fontFamily, startsWith('Figtree'));
      expect(text.displaySmall?.fontSize, 32);
      expect(text.headlineSmall?.fontSize, 24);
      expect(text.titleLarge?.fontSize, 20);
      expect(text.bodyLarge?.fontSize, 16);
      expect(text.bodySmall?.fontSize, 13);
      expect(text.labelSmall?.fontSize, 11);
    });

    test('cartao com raio 16 e sem elevacao', () {
      final card = AppTheme.light().cardTheme;
      final shape = card.shape! as RoundedRectangleBorder;

      expect(card.elevation, 0);
      expect(shape.borderRadius, BorderRadius.circular(AppRadius.card));
    });
  });
}
