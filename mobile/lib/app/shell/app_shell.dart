import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';

/// Destinos da barra inferior (frame "Navegação").
enum AppDestination {
  authorizations('Autorizações', Icons.verified_user_outlined),
  history('Histórico', Icons.history),
  profile('Perfil', Icons.person_outline);

  const AppDestination(this.label, this.icon);

  final String label;
  final IconData icon;
}

/// Casca das telas logadas: mantém o estado de cada aba e desenha a navegação
/// inferior. O conteúdo de cada aba vem do [navigationShell] do go_router.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: _BottomNavigation(
        currentIndex: navigationShell.currentIndex,
        onSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({
    required this.currentIndex,
    required this.onSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.hairline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (final destination in AppDestination.values) ...[
                  if (destination != AppDestination.values.first)
                    const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: _DestinationButton(
                      destination: destination,
                      selected: destination.index == currentIndex,
                      onTap: () => onSelected(destination.index),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DestinationButton extends StatelessWidget {
  const _DestinationButton({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final AppDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final color = selected ? palette.text : palette.textSecondary;

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.background : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.control),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(destination.icon, size: 20, color: color),
              const SizedBox(height: AppSpacing.xs),
              Text(
                destination.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodySmall?.copyWith(
                  fontSize: 11,
                  height: 1.35,
                  letterSpacing: 0,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
