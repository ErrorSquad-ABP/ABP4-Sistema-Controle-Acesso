import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'authorization_card.dart';
import 'authorization_contract.dart';
import 'authorization_state_view.dart';
import 'authorizations_controller.dart';

/// Tela principal do app (frame "Minhas autorizações"): cabeçalho, filtro,
/// lista e a ação de escanear. O Histórico é a mesma tela com o outro filtro.
class AuthorizationsPage extends ConsumerStatefulWidget {
  const AuthorizationsPage({
    super.key,
    this.initialFilter = AuthorizationFilter.active,
  });

  final AuthorizationFilter initialFilter;

  @override
  ConsumerState<AuthorizationsPage> createState() => _AuthorizationsPageState();
}

class _AuthorizationsPageState extends ConsumerState<AuthorizationsPage> {
  late AuthorizationFilter _filter = widget.initialFilter;

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(myAuthorizationsProvider);
    final now = ref.watch(clockProvider)();
    final controller = ref.read(myAuthorizationsProvider.notifier);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho, filtro e lista rolam juntos: com a fonte do sistema
            // ampliada, o título ocupa mais linhas e nada pode estourar.
            Expanded(
              child: _Content(
                page: page,
                filter: _filter,
                now: now,
                onFilterSelected: (filter) => setState(() => _filter = filter),
                onRefresh: controller.refresh,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.screen,
              ),
              child: _ScanAction(onPressed: () => context.push(AppRoutes.scan)),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({
    required this.page,
    required this.filter,
    required this.now,
    required this.onFilterSelected,
    required this.onRefresh,
  });

  final AsyncValue<AuthorizationPage> page;
  final AuthorizationFilter filter;
  final DateTime now;
  final ValueChanged<AuthorizationFilter> onFilterSelected;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.text,
      backgroundColor: palette.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.screen,
              AppSpacing.sm,
              AppSpacing.screen,
              0,
            ),
            sliver: SliverToBoxAdapter(child: _Header()),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
            sliver: SliverToBoxAdapter(
              child: _FilterTabs(
                selected: filter,
                onSelected: onFilterSelected,
              ),
            ),
          ),
          ..._bodySlivers(),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.xs)),
        ],
      ),
    );
  }

  List<Widget> _bodySlivers() => switch (page) {
    AsyncData(:final value) => _listSlivers(
      value.items.where((item) => filter.matches(item.status)).toList(),
    ),
    AsyncError() => [
      _stateSliver(AuthorizationStateView.error(onRetry: onRefresh)),
    ],
    _ => [_stateSliver(const AuthorizationStateView.loading())],
  };

  Widget _stateSliver(Widget child) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screen,
      AppSpacing.sm,
      AppSpacing.screen,
      0,
    ),
    sliver: SliverToBoxAdapter(child: child),
  );

  List<Widget> _listSlivers(List<Authorization> authorizations) {
    if (authorizations.isEmpty) {
      return [_stateSliver(const AuthorizationStateView.empty())];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          0,
        ),
        sliver: SliverList.separated(
          itemCount: authorizations.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => AuthorizationCard(
            key: ValueKey(authorizations[index].id),
            authorization: authorizations[index],
            now: now,
          ),
        ),
      ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SEU ACESSO',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Minhas autorizações',
                style: text.displaySmall?.copyWith(
                  height: 1.35,
                  letterSpacing: -0.96,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // Sem central de notificações nesta entrega: o sino é só do layout.
        Semantics(
          label: 'Notificações',
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: palette.hairline),
            ),
            child: Icon(
              Icons.notifications_none,
              size: 20,
              color: palette.text,
            ),
          ),
        ),
      ],
    );
  }
}

class _FilterTabs extends StatelessWidget {
  const _FilterTabs({required this.selected, required this.onSelected});

  final AuthorizationFilter selected;
  final ValueChanged<AuthorizationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.hairline,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          for (final (index, filter) in AuthorizationFilter.values.indexed) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: _FilterOption(
                filter: filter,
                selected: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FilterOption extends StatelessWidget {
  const _FilterOption({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final AuthorizationFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    // Raio 8 do Figma para a opção dentro do trilho.
    final radius = BorderRadius.circular(8);

    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: Center(
            child: Text(
              filter.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall?.copyWith(
                height: 1.35,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? palette.text : palette.textSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanAction extends StatelessWidget {
  const _ScanAction({required this.onPressed});

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
                    'Escanear QR Code',
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
