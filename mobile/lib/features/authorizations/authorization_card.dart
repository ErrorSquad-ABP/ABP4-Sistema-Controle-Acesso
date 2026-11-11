import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'authorization_contract.dart';
import 'authorization_format.dart';

/// Cartão da lista: local, janela, usos restantes e situação.
/// O chevron aponta para o detalhe, que ainda não existe no app.
class AuthorizationCard extends StatelessWidget {
  const AuthorizationCard({
    super.key,
    required this.authorization,
    required this.now,
  });

  final Authorization authorization;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // Expirada e cancelada não liberam mais acesso: o Figma esmaece o cartão.
    final inactive =
        authorization.status == AuthorizationStatus.expired ||
        authorization.status == AuthorizationStatus.canceled;

    return Opacity(
      opacity: inactive ? 0.65 : 1,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: palette.hairline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: palette.background,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(
                    Icons.apartment_outlined,
                    size: 24,
                    color: palette.textSecondary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _StatusChip(status: authorization.status),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorization.locationName,
                  style: text.titleLarge?.copyWith(height: 1.35),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  authorizationWindowLabel(
                    startsAt: authorization.startsAt,
                    endsAt: authorization.endsAt,
                    now: now,
                  ),
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _UsageBar(fraction: authorization.remainingFraction),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        '${authorization.remainingUses} de '
                        '${authorization.maxUses} usos restantes',
                        style: text.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: palette.textSecondary,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _UsageBar extends StatelessWidget {
  const _UsageBar({required this.fraction});

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

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final AuthorizationStatus status;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (background, dot, foreground) = switch (status) {
      AuthorizationStatus.active => (
        palette.successSoft,
        palette.success,
        palette.onSoft,
      ),
      AuthorizationStatus.expired => (
        palette.errorSoft,
        palette.error,
        palette.onSoft,
      ),
      AuthorizationStatus.scheduled => (
        // O frame só mostra ativa e expirada; agendada usa o token de atenção.
        palette.warningSoft,
        palette.warning,
        palette.onSoft,
      ),
      // Cancelada é condição neutra, sem cor (catálogo do design system).
      AuthorizationStatus.canceled => (
        Colors.transparent,
        palette.textSecondary,
        palette.textSecondary,
      ),
    };

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
