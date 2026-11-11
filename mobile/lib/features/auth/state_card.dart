import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Estados de tela do Figma ("Claro/Estado vazio", "… carregando", "… erro"):
/// um cartão de superfície com hairline, 24 de respiro e 16 entre os elementos.
///
/// Fica em `features/auth` porque é a tela de entrada que consome o estado de
/// carregamento hoje. Se as autorizações passarem a usar este cartão, ele migra
/// para `core/widgets` junto com o `FeedbackBanner`.
class StateCard extends StatelessWidget {
  /// Indicador girando e uma frase: o app esta trabalhando.
  const StateCard.loading({
    super.key,
    this.body = 'Carregando suas autorizações…',
  }) : icon = null,
       isLoading = true,
       title = null,
       onRetry = null;

  /// Nada para mostrar ainda, com a explicacao do proximo passo.
  const StateCard.empty({super.key})
    : icon = Icons.inbox_outlined,
      isLoading = false,
      title = 'Nenhuma autorização ainda',
      body = 'Suas liberações aparecerão aqui assim que forem criadas.',
      onRetry = null;

  /// A consulta falhou; a unica saida e tentar de novo.
  const StateCard.error({required this.onRetry, super.key})
    : icon = Icons.error_outline,
      isLoading = false,
      title = 'Não foi possível carregar',
      body = null;

  final IconData? icon;
  final bool isLoading;
  final String? title;
  final String? body;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    final children = <Widget>[
      Center(
        child: isLoading
            ? const SizedBox.square(
                dimension: 32,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            : Icon(icon, size: 32, color: palette.textSecondary),
      ),
      if (title != null)
        Text(title!, style: text.titleLarge, textAlign: TextAlign.center),
      if (body != null)
        Text(body!, style: text.bodySmall, textAlign: TextAlign.center),
      if (onRetry != null)
        OutlinedButton(
          onPressed: onRetry,
          child: const Text('Tentar novamente'),
        ),
    ];

    return Container(
      width: double.infinity,
      // Altura do frame (240) para os tres estados ocuparem o mesmo lugar.
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.hairline),
        borderRadius: BorderRadius.circular(AppRadius.card),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (index, child) in children.indexed) ...[
              if (index > 0) const SizedBox(height: AppSpacing.sm),
              child,
            ],
          ],
        ),
      ),
    );
  }
}
