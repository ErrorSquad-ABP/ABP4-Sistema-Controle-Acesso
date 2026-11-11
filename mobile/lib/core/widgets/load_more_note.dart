import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Rodapé de lista paginada: diz quanto já foi carregado e busca a próxima
/// página sob demanda. A primeira página continua rápida; o resto vem quando
/// a pessoa pede, com ou sem busca ativa.
class LoadMoreNote extends StatelessWidget {
  const LoadMoreNote({
    required this.message,
    required this.loading,
    required this.onPressed,
    super.key,
  });

  final String message;
  final bool loading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: palette.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Icon(
                  Icons.info_outline,
                  size: 20,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  message,
                  style: text.bodySmall?.copyWith(height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: loading ? null : onPressed,
            child: loading
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('Mostrar mais'),
                  ),
          ),
        ],
      ),
    );
  }
}
