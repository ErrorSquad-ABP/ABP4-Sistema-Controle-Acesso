import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_spacing.dart';
import 'app_typography.dart';

/// Temas claro e escuro do app, espelhando o design system do Figma.
///
/// Acoes primarias sao preto↔branco (nunca coloridas), a separacao e feita
/// por hairlines e nao ha sombras pesadas.
abstract final class AppTheme {
  static ThemeData light() => _build(AppPalette.light, Brightness.light);

  static ThemeData dark() => _build(AppPalette.dark, Brightness.dark);

  static ThemeData _build(AppPalette p, Brightness brightness) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: p.text,
      onPrimary: p.background,
      secondary: p.textSecondary,
      onSecondary: p.background,
      error: p.error,
      onError: AppPalette.light.surface,
      errorContainer: p.errorSoft,
      onErrorContainer: p.onSoft,
      surface: p.surface,
      onSurface: p.text,
      onSurfaceVariant: p.textSecondary,
      surfaceContainerHighest: p.surface,
      outline: p.hairline,
      outlineVariant: p.hairline,
      shadow: Colors.transparent,
      surfaceTint: Colors.transparent,
    );

    final textTheme = AppTypography.textTheme(
      primary: p.text,
      secondary: p.textSecondary,
    );

    const controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(AppRadius.control)),
    );
    const minControlSize = Size(64, AppSpacing.controlHeight);

    OutlineInputBorder inputBorder(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: p.background,
      canvasColor: p.background,
      fontFamily: AppTypography.fontFamily,
      textTheme: textTheme,
      extensions: [p],
      splashFactory: NoSplash.splashFactory,
      appBarTheme: AppBarThemeData(
        backgroundColor: p.background,
        foregroundColor: p.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: p.text,
          foregroundColor: p.background,
          minimumSize: minControlSize,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          textStyle: textTheme.labelLarge,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: minControlSize,
          shape: controlShape,
          side: BorderSide(color: p.hairline),
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: p.text,
          minimumSize: minControlSize,
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: p.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        constraints: const BoxConstraints(minHeight: AppSpacing.controlHeight),
        hintStyle: textTheme.bodyMedium,
        prefixIconColor: p.textSecondary,
        suffixIconColor: p.textSecondary,
        border: inputBorder(p.hairline),
        enabledBorder: inputBorder(p.hairline),
        focusedBorder: inputBorder(p.text, 1.5),
        errorBorder: inputBorder(p.error),
        focusedErrorBorder: inputBorder(p.error, 1.5),
        errorStyle: textTheme.bodySmall?.copyWith(color: p.error),
      ),
      cardTheme: CardThemeData(
        color: p.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: p.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: p.hairline, thickness: 1, space: 1),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: p.surface,
        indicatorColor: p.background,
        elevation: 0,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => textTheme.bodySmall?.copyWith(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? p.text
                : p.textSecondary,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: p.text),
      iconTheme: IconThemeData(color: p.text),
    );
  }
}
