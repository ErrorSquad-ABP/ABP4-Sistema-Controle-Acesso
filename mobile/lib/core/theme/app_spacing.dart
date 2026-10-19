/// Grid de 8 pontos e raios do design system.
abstract final class AppSpacing {
  static const double xs = 8;
  static const double sm = 16;
  static const double md = 24;
  static const double lg = 32;
  static const double xl = 48;

  /// Margem lateral padrao das telas.
  static const double screen = md;

  /// Altura minima de toque de campos e botoes.
  static const double controlHeight = 56;
}

abstract final class AppRadius {
  /// Controles: campos e botoes secundarios.
  static const double control = 12;

  /// Cartoes.
  static const double card = 16;

  /// Capsulas: chips e botao primario.
  static const double pill = 999;
}
