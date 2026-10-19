import 'package:flutter/material.dart';

/// Tokens de cor do design system "Monochrome Premium" (design/README.md).
///
/// A base e monocromatica; cor aparece apenas como feedback de estado.
/// Os tons de feedback (e seus fundos suaves) sao iguais nos dois temas.
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  const AppPalette({
    required this.background,
    required this.surface,
    required this.text,
    required this.textSecondary,
    required this.hairline,
    required this.success,
    required this.successSoft,
    required this.error,
    required this.errorSoft,
    required this.warning,
    required this.warningSoft,
  });

  static const Color _success = Color(0xFF16A34A);
  static const Color _successSoft = Color(0xFFECFDF3);
  static const Color _error = Color(0xFFDC2626);
  static const Color _errorSoft = Color(0xFFFEF2F2);
  static const Color _warning = Color(0xFFD97706);
  static const Color _warningSoft = Color(0xFFFFFBEB);

  static const AppPalette light = AppPalette(
    background: Color(0xFFFAFAFA),
    surface: Color(0xFFFFFFFF),
    text: Color(0xFF0A0A0A),
    textSecondary: Color(0xFF6E6E6E),
    hairline: Color(0xFFE8E8E8),
    success: _success,
    successSoft: _successSoft,
    error: _error,
    errorSoft: _errorSoft,
    warning: _warning,
    warningSoft: _warningSoft,
  );

  static const AppPalette dark = AppPalette(
    background: Color(0xFF0A0A0A),
    surface: Color(0xFF161616),
    text: Color(0xFFFAFAFA),
    textSecondary: Color(0xFFA3A3A3),
    hairline: Color(0xFF262626),
    success: _success,
    successSoft: _successSoft,
    error: _error,
    errorSoft: _errorSoft,
    warning: _warning,
    warningSoft: _warningSoft,
  );

  final Color background;
  final Color surface;
  final Color text;
  final Color textSecondary;
  final Color hairline;
  final Color success;
  final Color successSoft;
  final Color error;
  final Color errorSoft;
  final Color warning;
  final Color warningSoft;

  /// Texto sobre os fundos suaves de feedback: sempre escuro, nos dois temas.
  Color get onSoft => light.text;

  @override
  AppPalette copyWith({
    Color? background,
    Color? surface,
    Color? text,
    Color? textSecondary,
    Color? hairline,
    Color? success,
    Color? successSoft,
    Color? error,
    Color? errorSoft,
    Color? warning,
    Color? warningSoft,
  }) {
    return AppPalette(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      text: text ?? this.text,
      textSecondary: textSecondary ?? this.textSecondary,
      hairline: hairline ?? this.hairline,
      success: success ?? this.success,
      successSoft: successSoft ?? this.successSoft,
      error: error ?? this.error,
      errorSoft: errorSoft ?? this.errorSoft,
      warning: warning ?? this.warning,
      warningSoft: warningSoft ?? this.warningSoft,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) {
      return this;
    }
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      hairline: Color.lerp(hairline, other.hairline, t)!,
      success: Color.lerp(success, other.success, t)!,
      successSoft: Color.lerp(successSoft, other.successSoft, t)!,
      error: Color.lerp(error, other.error, t)!,
      errorSoft: Color.lerp(errorSoft, other.errorSoft, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningSoft: Color.lerp(warningSoft, other.warningSoft, t)!,
    );
  }
}

/// Atalho para ler a paleta do tema atual: `context.palette.success`.
extension AppPaletteContext on BuildContext {
  AppPalette get palette => Theme.of(this).extension<AppPalette>()!;
}
