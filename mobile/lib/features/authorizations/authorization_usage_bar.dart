import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Barra de 3 px dos usos restantes: trilho hairline e preenchimento na cor
/// do texto (lista e detalhe).
class AuthorizationUsageBar extends StatelessWidget {
  const AuthorizationUsageBar({super.key, required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: Container(
        height: 3,
        color: palette.hairline,
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.clamp(0, 1),
          heightFactor: 1,
          child: ColoredBox(color: palette.text),
        ),
      ),
    );
  }
}
