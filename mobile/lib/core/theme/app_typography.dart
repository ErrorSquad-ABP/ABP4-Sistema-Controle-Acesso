import 'package:flutter/material.dart';

/// Escala tipografica Figtree do design system.
///
/// Display 32 · Titulo 24 · Cabecalho 20 · Corpo 16 · Legenda 13 · Micro 11
/// (caixa alta, espacamento de 8%). A fonte vem empacotada em
/// `assets/fonts/figtree/` (declarada no pubspec), sem download em runtime.
abstract final class AppTypography {
  static const String fontFamily = 'Figtree';

  static TextTheme textTheme({
    required Color primary,
    required Color secondary,
  }) {
    final theme = TextTheme(
      // Display
      displaySmall: TextStyle(
        fontSize: 32,
        height: 1.2,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: primary,
      ),
      // Titulo
      headlineSmall: TextStyle(
        fontSize: 24,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Cabecalho
      titleLarge: TextStyle(
        fontSize: 20,
        height: 1.3,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        height: 1.4,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Corpo
      bodyLarge: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: primary,
      ),
      bodyMedium: TextStyle(
        fontSize: 16,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      // Legenda
      bodySmall: TextStyle(
        fontSize: 13,
        height: 1.4,
        fontWeight: FontWeight.w400,
        color: secondary,
      ),
      labelLarge: TextStyle(
        fontSize: 16,
        height: 1.25,
        fontWeight: FontWeight.w600,
        color: primary,
      ),
      // Micro (aplicar em caixa alta no texto)
      labelSmall: TextStyle(
        fontSize: 11,
        height: 1.3,
        fontWeight: FontWeight.w500,
        letterSpacing: 11 * 0.08,
        color: secondary,
      ),
    );
    return theme.apply(fontFamily: fontFamily);
  }
}
