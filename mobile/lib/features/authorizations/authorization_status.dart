import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'authorization_contract.dart';

/// Cores de feedback de uma situação: fundo, ponto e texto do chip.
typedef AuthorizationStatusTone = ({
  Color background,
  Color dot,
  Color foreground,
});

AuthorizationStatusTone authorizationStatusTone(
  AppPalette palette,
  AuthorizationStatus status,
) => switch (status) {
  AuthorizationStatus.active => (
    background: palette.successSoft,
    dot: palette.success,
    foreground: palette.onSoft,
  ),
  AuthorizationStatus.expired => (
    background: palette.errorSoft,
    dot: palette.error,
    foreground: palette.onSoft,
  ),
  AuthorizationStatus.scheduled => (
    // O frame só mostra ativa e expirada; agendada usa o token de atenção.
    background: palette.warningSoft,
    dot: palette.warning,
    foreground: palette.onSoft,
  ),
  // Cancelada é condição neutra, sem cor (catálogo do design system).
  AuthorizationStatus.canceled => (
    background: Colors.transparent,
    dot: palette.textSecondary,
    foreground: palette.textSecondary,
  ),
};

/// Chip da situação, igual na lista e no detalhe.
class AuthorizationStatusChip extends StatelessWidget {
  const AuthorizationStatusChip({super.key, required this.status});

  final AuthorizationStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (:background, :dot, :foreground) = authorizationStatusTone(
      palette,
      status,
    );

    return Container(
      // 12/8 do Figma: o horizontal não cai na grade de 8.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              status.label,
              style: text.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
