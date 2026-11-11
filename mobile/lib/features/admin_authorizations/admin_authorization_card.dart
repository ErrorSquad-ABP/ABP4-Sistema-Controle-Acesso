import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../authorizations/authorization_contract.dart';
import '../authorizations/authorization_format.dart';
import '../authorizations/authorization_status.dart';

/// Cartão da lista de administração: o mesmo desenho do cartão de
/// autorizações do usuário (ícone de 48, chip de situação, nome em 20/600,
/// linha da janela e chevron), com a pessoa que recebeu a liberação.
class AdminAuthorizationCard extends StatelessWidget {
  const AdminAuthorizationCard({
    super.key,
    required this.authorization,
    required this.now,
    this.onTap,
    this.onCancel,
  });

  final Authorization authorization;
  final DateTime now;
  final VoidCallback? onTap;

  /// Nulo quando a situação não pode mais ser cancelada (o backend devolveria
  /// 409): a ação some em vez de falhar.
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // Expirada e cancelada não liberam mais acesso: o Figma esmaece o cartão.
    final inactive =
        authorization.status == AuthorizationStatus.expired ||
        authorization.status == AuthorizationStatus.canceled;
    final onCancel = this.onCancel;

    return Opacity(
      opacity: inactive ? 0.65 : 1,
      child: Semantics(
        button: onTap != null,
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
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
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
                      const SizedBox(height: 4),
                      Text(
                        authorization.person.display,
                        style: text.bodySmall?.copyWith(height: 1.35),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Row(
                    children: [
                      Expanded(
                        child: onCancel == null
                            ? const SizedBox.shrink()
                            : Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: onCancel,
                                  child: const Text('Cancelar'),
                                ),
                              ),
                      ),
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
      ),
    );
  }
}
