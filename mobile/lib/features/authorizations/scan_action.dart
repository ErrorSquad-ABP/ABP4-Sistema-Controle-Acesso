import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Ação primária pill de 56 px com o ícone de leitura no círculo à direita.
/// A lista usa "Escanear QR Code" e o detalhe, "Escanear agora".
class ScanAction extends StatelessWidget {
  const ScanAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      height: AppSpacing.controlHeight,
      child: Material(
        color: palette.text,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.xs,
              0,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelLarge?.copyWith(color: palette.background),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.background,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.qr_code_scanner,
                      size: 20,
                      color: palette.text,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
