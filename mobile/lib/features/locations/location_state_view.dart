import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Cartão único que ocupa a área da lista nos estados vazio, carregando e
/// erro, no mesmo desenho dos estados da tela de autorizações.
class LocationStateView extends StatelessWidget {
  const LocationStateView._({
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  const LocationStateView.loading()
    : this._(icon: null, title: 'Carregando os locais…');

  const LocationStateView.empty()
    : this._(
        icon: Icons.inbox_outlined,
        title: 'Nenhum local cadastrado',
        message: 'Os locais ativos do condomínio aparecerão aqui.',
      );

  const LocationStateView.error({
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
            if (message case final message?) ...[
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
