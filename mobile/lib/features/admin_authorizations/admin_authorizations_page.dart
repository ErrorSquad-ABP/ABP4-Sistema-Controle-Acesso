import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/clock.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/load_more_note.dart';
import '../auth/auth_contract.dart';
import '../auth/session_controller.dart';
import '../authorizations/authorization_contract.dart';
import 'admin_authorization_card.dart';
import 'admin_authorization_contract.dart';
import 'admin_authorization_form_page.dart';
import 'admin_authorizations_controller.dart';
import 'cancel_authorization_dialog.dart';

/// Administração das autorizações (US-30). Não existe frame no Figma: segue o
/// cabeçalho, os cartões e os estados da tela de locais.
class AdminAuthorizationsPage extends ConsumerStatefulWidget {
  const AdminAuthorizationsPage({super.key});

  @override
  ConsumerState<AdminAuthorizationsPage> createState() =>
      _AdminAuthorizationsPageState();
}

class _AdminAuthorizationsPageState
    extends ConsumerState<AdminAuthorizationsPage> {
  final _search = TextEditingController();
  bool _loadingMore = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _openForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (context) => const AdminAuthorizationFormPage(),
      ),
    );
    // O formulário devolve true quando a autorização foi criada.
    if (created == true && mounted) {
      await ref.read(adminAuthorizationsProvider.notifier).refresh();
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      await ref.read(adminAuthorizationsProvider.notifier).loadMore();
    } catch (error) {
      // A página 1 continua na tela; só avisa que a próxima não veio.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_listFailureMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _cancel(Authorization authorization) async {
    final canceled = await showCancelAuthorizationDialog(
      context,
      authorization: authorization,
    );
    if (canceled != true) return;
    await ref.read(adminAuthorizationsProvider.notifier).refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Autorização cancelada.')));
  }

  List<Authorization> _visible(List<Authorization> items) {
    final query = searchFold(_search.text.trim());
    if (query.isEmpty) return items;
    return [
      for (final item in items)
        if (searchFold(item.locationName).contains(query) ||
            searchFold(item.person.name).contains(query))
          item,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(adminAuthorizationsProvider);
    final now = ref.watch(clockProvider)();
    final isAdmin =
        ref.watch(currentSessionProvider)?.user.role == UserRole.admin;
    final controller = ref.read(adminAuthorizationsProvider.notifier);
    final filter = controller.filter;
    final query = _search.text.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabeçalho, busca, filtro e lista rolam juntos: com a fonte do
            // sistema ampliada, o título ocupa mais linhas e nada estoura.
            Expanded(
              child: RefreshIndicator(
                onRefresh: controller.refresh,
                color: context.palette.text,
                backgroundColor: context.palette.surface,
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
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.sm,
                        AppSpacing.screen,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _SearchField(
                          controller: _search,
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: _FilterChips(
                          selected: filter,
                          onSelected: controller.setFilter,
                        ),
                      ),
                    ),
                    ..._bodySlivers(page, now, query, filter),
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.xs),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screen,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isAdmin)
                      _NewAuthorizationAction(onPressed: _openForm)
                    else
                      const _AdminOnlyNote(),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _bodySlivers(
    AsyncValue<AuthorizationPage> page,
    DateTime now,
    String query,
    AdminAuthorizationFilter filter,
  ) {
    final Widget state;
    switch (page) {
      case AsyncData(:final value):
        final visible = _visible(value.items);
        if (visible.isEmpty) {
          state = value.items.isEmpty && query.isEmpty
              ? _StateView.empty(filter: filter)
              : const _StateView.noResults();
          return [
            _stateSliver(state),
            // Com a busca ativa, o que ainda não foi carregado pode conter o
            // que a pessoa procura: "Mostrar mais" continua disponível.
            if (value.items.length < value.total) _loadMoreSliver(value),
          ];
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
              itemCount: visible.length,
              separatorBuilder: (context, index) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final authorization = visible[index];
                return AdminAuthorizationCard(
                  key: ValueKey(authorization.id),
                  authorization: authorization,
                  now: now,
                  onTap: () => context.push(
                    AppRoutes.authorizationDetail(authorization.id),
                  ),
                  onCancel: canCancelAuthorization(authorization.status)
                      ? () => _cancel(authorization)
                      : null,
                );
              },
            ),
          ),
          if (value.items.length < value.total) _loadMoreSliver(value),
        ];
      case AsyncError(:final error):
        state = _StateView.error(
          message: _listFailureMessage(error),
          onRetry: () =>
              ref.read(adminAuthorizationsProvider.notifier).refresh(),
        );
      default:
        state = const _StateView.loading();
    }

    return [_stateSliver(state)];
  }

  Widget _stateSliver(Widget child) => SliverPadding(
    padding: const EdgeInsets.fromLTRB(
      AppSpacing.screen,
      AppSpacing.sm,
      AppSpacing.screen,
      0,
    ),
    sliver: SliverToBoxAdapter(child: child),
  );

  Widget _loadMoreSliver(AuthorizationPage page) => _stateSliver(
    LoadMoreNote(
      key: const Key('load-more-authorizations'),
      message:
          'Mostrando ${page.items.length} de ${page.total} autorizações.',
      loading: _loadingMore,
      onPressed: _loadMore,
    ),
  );
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
                'ADMINISTRAÇÃO',
                style: text.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Autorizações',
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

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return TextField(
      key: const Key('admin-search'),
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: text.bodyLarge?.copyWith(height: 1.35),
      decoration: InputDecoration(
        hintText: 'Buscar por pessoa ou local',
        prefixIcon: const Icon(Icons.search, size: 20),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                tooltip: 'Limpar busca',
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              ),
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onSelected});

  final AdminAuthorizationFilter selected;
  final ValueChanged<AdminAuthorizationFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Trilho horizontal: com a fonte ampliada os cinco chips não cabem na
    // largura de um celular pequeno.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.screen),
      child: Row(
        children: [
          for (final filter in AdminAuthorizationFilter.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.xs),
              child: _FilterChip(
                filter: filter,
                selected: filter == selected,
                onTap: () => onSelected(filter),
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.filter,
    required this.selected,
    required this.onTap,
  });

  final AdminAuthorizationFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Material(
          color: selected ? palette.text : Colors.transparent,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? palette.text : palette.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Center(
              widthFactor: 1,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 12,
                ),
                child: Text(
                  filter.label,
                  maxLines: 1,
                  style: text.bodySmall?.copyWith(
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? palette.background : palette.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StateView extends StatelessWidget {
  const _StateView._({
    required this.icon,
    required this.title,
    this.message,
    this.onRetry,
  });

  const _StateView.loading()
    : this._(icon: null, title: 'Carregando as autorizações…');

  factory _StateView.empty({required AdminAuthorizationFilter filter}) =>
      _StateView._(
        icon: Icons.inbox_outlined,
        title: 'Nenhuma autorização',
        message: filter == AdminAuthorizationFilter.all
            ? 'As autorizações criadas aparecerão aqui.'
            : 'Nenhuma autorização com a situação “${filter.label}”.',
      );

  const _StateView.noResults()
    : this._(
        icon: Icons.search_off,
        title: 'Nenhuma autorização encontrada',
        message: 'Ajuste a busca ou troque a situação do filtro.',
      );

  const _StateView.error({
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

class _NewAuthorizationAction extends StatelessWidget {
  const _NewAuthorizationAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Nova autorização',
      child: SizedBox(
        key: const Key('new-admin-authorization-action'),
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
                      'Nova autorização',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.labelLarge?.copyWith(
                        color: palette.background,
                      ),
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
                      child: Icon(Icons.add, size: 20, color: palette.text),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `GET/POST /authorizations` exigem ADMIN: em vez de esconder o motivo, a
/// tela explica por que não há ação.
class _AdminOnlyNote extends StatelessWidget {
  const _AdminOnlyNote();

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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, size: 20, color: palette.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              'Só administradores criam e cancelam autorizações. Peça a um '
              'administrador para liberar o acesso.',
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

String _listFailureMessage(Object error) {
  if (error is! AdminFailure) {
    return 'Não foi possível carregar as autorizações. Tente novamente.';
  }
  return switch (error.reason) {
    AdminFailureReason.unauthorized => 'Sua sessão expirou. Entre novamente.',
    AdminFailureReason.forbidden =>
      'Seu perfil não pode administrar autorizações.',
    AdminFailureReason.notFound => 'A autorização não existe mais.',
    AdminFailureReason.conflict || AdminFailureReason.invalidRequest =>
      'O servidor recusou a consulta de autorizações.',
    AdminFailureReason.unprocessable || AdminFailureReason.unexpected =>
      'O servidor respondeu de um jeito inesperado. Tente novamente.',
    AdminFailureReason.unavailable =>
      'O serviço de autorizações está fora do ar. Tente novamente em '
          'instantes.',
    AdminFailureReason.network =>
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    AdminFailureReason.timeout =>
      'O servidor demorou para responder. Tente novamente em instantes.',
  };
}
