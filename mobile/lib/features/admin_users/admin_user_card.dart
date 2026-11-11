import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_contract.dart';
import 'admin_users_contract.dart';

/// Cartão da lista de pessoas: nome, e-mail, perfil e situação. Tocar abre a
/// conta para editar.
class AdminUserCard extends StatelessWidget {
  const AdminUserCard({super.key, required this.user, required this.onTap});

  final AdminUser user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      container: true,
      label: user.accessibleLabel,
      excludeSemantics: true,
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
                    // As iniciais repetem o nome do cartão: só decoração.
                    ExcludeSemantics(
                      child: Container(
                        width: 48,
                        height: 48,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: palette.background,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.hairline),
                        ),
                        child: Text(
                          user.initials,
                          style: text.bodyLarge?.copyWith(
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: text.titleMedium?.copyWith(height: 1.35),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.email,
                            style: text.bodySmall?.copyWith(height: 1.35),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: palette.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    _RoleChip(role: user.role),
                    _AccountStatusChip(active: user.active),
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

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      // 12/8 do Figma: o horizontal não cai na grade de 8.
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.hairline),
      ),
      child: Text(
        role.label,
        style: text.bodySmall?.copyWith(
          fontWeight: FontWeight.w500,
          color: palette.text,
        ),
      ),
    );
  }
}

class _AccountStatusChip extends StatelessWidget {
  const _AccountStatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final (background, dot) = active
        ? (palette.successSoft, palette.success)
        : (palette.errorSoft, palette.error);

    return Container(
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
          Text(
            active ? 'Ativa' : 'Inativa',
            style: text.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
              color: palette.onSoft,
            ),
          ),
        ],
      ),
    );
  }
}
