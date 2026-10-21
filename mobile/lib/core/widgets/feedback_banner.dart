import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

enum FeedbackTone { success, error, warning }

/// Aviso de estado (sucesso, erro ou atenção) sobre o tom suave do design system.
///
/// Texto e ícone usam `onSoft`, que mantém contraste AA nos dois temas; o tom
/// do estado fica no fundo suave e no ícone escolhido.
class FeedbackBanner extends StatelessWidget {
  const FeedbackBanner({required this.tone, required this.message, super.key});

  final FeedbackTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (Color soft, IconData icon) = switch (tone) {
      FeedbackTone.success => (palette.successSoft, Icons.check_circle_outline),
      FeedbackTone.error => (palette.errorSoft, Icons.error_outline),
      FeedbackTone.warning => (palette.warningSoft, Icons.info_outline),
    };
    final text = Theme.of(context).textTheme;

    return Semantics(
      container: true,
      liveRegion: true,
      label: message,
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: soft,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: palette.onSoft),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                message,
                style: text.bodySmall?.copyWith(color: palette.onSoft),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
