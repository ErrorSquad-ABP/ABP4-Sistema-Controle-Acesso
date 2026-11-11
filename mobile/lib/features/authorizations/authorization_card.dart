import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'authorization_contract.dart';
import 'authorization_format.dart';
import 'authorization_status.dart';
import 'authorization_usage_bar.dart';

/// Cartão da lista: local, janela, usos restantes e situação. Tocar abre o
/// detalhe.
class AuthorizationCard extends StatelessWidget {
  const AuthorizationCard({
    super.key,
    required this.authorization,
    required this.now,
    this.onTap,
  });

  final Authorization authorization;
  final DateTime now;
  final VoidCallback? onTap;

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
      child: Material(
        color: palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.card),
          side: BorderSide(color: palette.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
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
                        child: AuthorizationStatusChip(
                          status: authorization.status,
                        ),
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
                          AuthorizationUsageBar(
                            fraction: authorization.remainingFraction,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            remainingUsesLabel(
                              remaining: authorization.remainingUses,
                              max: authorization.maxUses,
                            ),
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
        ),
      ),
    );
  }
}
