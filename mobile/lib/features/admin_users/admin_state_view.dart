import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Cartão único que ocupa a área da lista nos estados vazio, carregando e
/// erro, no mesmo desenho dos estados de locais e autorizações.
class AdminStateView extends StatelessWidget {
  const AdminStateView._({
    required this.icon,
    required this.title,
    required this.message,
    this.onRetry,
  });

  const AdminStateView.loading({required String title})
    : this._(icon: null, title: title, message: null);

  const AdminStateView.empty({
    required IconData icon,
    required String title,
    required String message,
  }) : this._(icon: icon, title: title, message: message);

  const AdminStateView.error({
    required String message,
    required VoidCallback onRetry,
  }) : this._(
         icon: Icons.error_outline,
         title: 'Não foi possível carregar',
         message: message,
         onRetry: onRetry,
       );

  final IconData? icon;
  final String title;
  final String? message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final retry = onRetry;
    final message = this.message;

    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: palette.hairline),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (retry == null) ...[
              Center(
                child: icon == null
                    ? const SizedBox.square(
                        dimension: 32,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    : Icon(icon, size: 32, color: palette.textSecondary),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: retry == null && icon == null
                  ? text.bodyLarge?.copyWith(height: 1.35)
                  : text.titleLarge?.copyWith(height: 1.35),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(height: 1.35),
              ),
            ],
            if (retry != null) ...[
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: retry,
                child: const FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('Tentar novamente'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
