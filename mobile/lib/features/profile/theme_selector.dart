import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_mode_provider.dart';

/// Seletor Claro/Escuro do frame "Aparência". O estado é o
/// [themeModeProvider]: a tela não guarda tema próprio.
class ThemeSelector extends ConsumerWidget {
  const ThemeSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final notifier = ref.read(themeModeProvider.notifier);

    // Trilho de 56 com 4 de respiro; no escuro ele se funde ao fundo e só a
    // hairline separa.
    return Container(
      height: AppSpacing.controlHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? palette.background : palette.hairline,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      // A hairline pinta por cima para não encolher a área de toque da opção.
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: palette.hairline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _ThemeOption(
              label: 'Claro',
              icon: Icons.light_mode_outlined,
              selected: !isDark,
              onTap: () => notifier.set(ThemeMode.light),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _ThemeOption(
              label: 'Escuro',
              icon: Icons.dark_mode_outlined,
              selected: isDark,
              onTap: () => notifier.set(ThemeMode.dark),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // A opção escolhida inverte o contraste do trilho nos dois temas.
    final background = selected
        ? (isDark ? palette.text : palette.surface)
        : Colors.transparent;
    final foreground = selected
        ? (isDark ? palette.background : palette.text)
        : palette.textSecondaryStrong;
    final radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      button: true,
      selected: selected,
      label: 'Tema ${label.toLowerCase()}',
      excludeSemantics: true,
      child: Material(
        color: background,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
