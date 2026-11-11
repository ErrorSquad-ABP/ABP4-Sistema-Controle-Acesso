import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Cartão único que ocupa a área da lista nos estados vazio, carregando e
/// erro (frames 10:13961, 10:13966 e 10:13970).
class AuthorizationStateView extends StatelessWidget {
  const AuthorizationStateView._({
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  const AuthorizationStateView.loading()
    : this._(
        icon: null,
        title: 'Carregando suas autorizações…',
        message: null,
        onRetry: null,
      );

  const AuthorizationStateView.empty()
    : this._(
        icon: Icons.inbox_outlined,
        title: 'Nenhuma autorização ainda',
        message: 'Suas liberações aparecerão aqui assim que forem criadas.',
        onRetry: null,
      );

  const AuthorizationStateView.error({required VoidCallback onRetry})
    : this._(
        icon: Icons.error_outline,
        title: 'Não foi possível carregar',
        message: null,
        onRetry: onRetry,
      );

  /// Carregando do detalhe: o texto da lista fala em várias autorizações.
  const AuthorizationStateView.loadingDetail()
    : this._(
        icon: null,
        title: 'Carregando a autorização…',
        message: null,
        onRetry: null,
      );

  /// 404 (ou id inválido): sem botão; a linha de retorno fica acima do cartão.
  const AuthorizationStateView.notFound()
    : this._(
        icon: Icons.search_off,
        title: 'Autorização não encontrada',
        message: 'Ela pode ter sido removida ou o link não existe mais.',
        onRetry: null,
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
            Center(
              child: icon == null
                  ? const SizedBox.square(
                      dimension: 32,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  : Icon(icon, size: 32, color: palette.textSecondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              title,
              textAlign: TextAlign.center,
              style: icon == null
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
