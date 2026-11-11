import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/widgets/load_more_note.dart';
import '../auth/auth_contract.dart';
import '../auth/session_controller.dart';
import 'access_event_card.dart';
import 'access_events_contract.dart';
import 'access_history_controller.dart';
import 'admin_form.dart';
import 'admin_state_view.dart';
import 'admin_user_card.dart';
import 'admin_user_detail_page.dart';
import 'admin_users_contract.dart';
import 'admin_users_controller.dart';
import 'new_admin_user_page.dart';

/// Abas internas da administração de pessoas.
enum AdminUsersTab {
  users('Usuários'),
  history('Histórico');

  const AdminUsersTab(this.label);

  final String label;
}

/// Tela de administração de usuários (US-31), aberta a partir do Perfil.
///
/// Não existe frame no Figma: a tela segue o cabeçalho ADMINISTRAÇÃO, os
/// cartões e a pill de ação das telas de locais e autorizações.
class AdminUsersPage extends ConsumerStatefulWidget {
  const AdminUsersPage({super.key});

  @override
  ConsumerState<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends ConsumerState<AdminUsersPage> {
  AdminUsersTab _tab = AdminUsersTab.users;
  final _search = TextEditingController();
  bool _loadingMoreUsers = false;
  bool _loadingMoreHistory = false;

  @override
  void initState() {
    super.initState();
    // A busca vive no provider: ao reabrir a tela o campo mostra o termo que
    // ainda está filtrando a lista, em vez de parecer vazio.
    _search.text = ref.read(adminUsersSearchProvider);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// A busca só vai ao servidor quando a pessoa confirma; digitar não dispara
  /// uma consulta por tecla.
  Future<void> _submitSearch() async {
    final term = _search.text.trim();
    if (term == ref.read(adminUsersSearchProvider)) {
      await ref.read(adminUsersProvider.notifier).refresh();
      return;
    }
    ref.read(adminUsersSearchProvider.notifier).search(term);
  }

  void _clearSearch() {
    if (_search.text.isEmpty) return;
    _search.clear();
    setState(() {});
    ref.read(adminUsersSearchProvider.notifier).search('');
  }

  Future<void> _openUser(AdminUser user) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (context) => AdminUserDetailPage(id: user.id),
      ),
    );
  }

  Future<void> _openCreate() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const NewAdminUserPage()),
    );
    // O formulário devolve true quando a conta foi criada.
    if (created == true && mounted) {
      await ref.read(adminUsersProvider.notifier).refresh();
    }
  }

  /// Próxima página de contas. A página 1 continua na tela se ela falhar.
  Future<void> _loadMoreUsers() async {
    if (_loadingMoreUsers) return;
    setState(() => _loadingMoreUsers = true);
    try {
      await ref.read(adminUsersProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_usersFailureMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _loadingMoreUsers = false);
    }
  }

  /// Próxima página do histórico. A página 1 continua na tela se ela falhar.
  Future<void> _loadMoreHistory() async {
    if (_loadingMoreHistory) return;
    setState(() => _loadingMoreHistory = true);
    try {
      await ref.read(accessHistoryProvider.notifier).loadMore();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_historyFailureMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _loadingMoreHistory = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final tab = _tab;
    final users = ref.watch(adminUsersProvider);
    // A aba Histórico só consulta quando é aberta: a lista de contas é a
    // entrada da tela e não paga por uma segunda chamada.
    final history = tab == AdminUsersTab.history
        ? ref.watch(accessHistoryProvider)
        : null;
    final filter = ref.watch(accessDecisionFilterProvider);
    final now = ref.watch(clockProvider)();
    final isAdmin =
        ref.watch(currentSessionProvider)?.user.role == UserRole.admin;
    final search = ref.watch(adminUsersSearchProvider);

    final onRefresh = tab == AdminUsersTab.users
        ? ref.read(adminUsersProvider.notifier).refresh
        : ref.read(accessHistoryProvider.notifier).refresh;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                color: palette.text,
                backgroundColor: palette.surface,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.xs,
                        AppSpacing.screen,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _BackRow(
                          onTap: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.sm,
                        AppSpacing.screen,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _Header(
                          title: switch (tab) {
                            AdminUsersTab.users => 'Usuários',
                            AdminUsersTab.history => 'Histórico de acessos',
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.screen,
                        AppSpacing.sm,
                        AppSpacing.screen,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _Tabs(
                          selected: tab,
                          onSelected: (next) => setState(() => _tab = next),
                        ),
                      ),
                    ),
                    ...switch (tab) {
                      AdminUsersTab.users => _usersSlivers(users, search),
                      AdminUsersTab.history => _historySlivers(
                        history ?? const AsyncLoading(),
                        filter,
                        now,
                      ),
                    },
                    const SliverToBoxAdapter(
                      child: SizedBox(height: AppSpacing.sm),
                    ),
                  ],
                ),
              ),
            ),
            if (tab == AdminUsersTab.users)
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
                        AdminPrimaryAction(
                          key: const Key('new-user-action'),
                          label: 'Novo usuário',
                          icon: Icons.person_add_alt_1,
                          onPressed: _openCreate,
                        )
                      else
                        const _InfoNote(
                          icon: Icons.lock_outline,
                          message:
                              'Só administradores gerenciam contas. Peça a um '
                              'administrador para incluir ou alterar usuários.',
                        ),
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

  List<Widget> _usersSlivers(AsyncValue<AdminUserPage> users, String search) {
    final controller = ref.read(adminUsersProvider.notifier);
    final searchSliver = SliverPadding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        0,
      ),
      sliver: SliverToBoxAdapter(
        child: _SearchField(
          controller: _search,
          onChanged: () => setState(() {}),
          onSubmitted: _submitSearch,
          onClear: _clearSearch,
        ),
      ),
    );

    return [
      searchSliver,
      ...switch (users) {
        AsyncData(:final value) => _userListSlivers(value, search),
        AsyncError(:final error) => [
          _stateSliver(
            AdminStateView.error(
              message: _usersFailureMessage(error),
              onRetry: controller.refresh,
            ),
          ),
        ],
        _ => [
          _stateSliver(
            const AdminStateView.loading(title: 'Carregando as contas…'),
          ),
        ],
      },
    ];
  }

  List<Widget> _userListSlivers(AdminUserPage page, String search) {
    if (page.items.isEmpty) {
      return [
        _stateSliver(
          search.isEmpty
              ? const AdminStateView.empty(
                  icon: Icons.group_outlined,
                  title: 'Nenhuma conta cadastrada',
                  message:
                      'As contas do condomínio aparecerão aqui. Use '
                      '"Novo usuário" para criar a primeira.',
                )
              : const AdminStateView.empty(
                  icon: Icons.search_off,
                  title: 'Nenhuma conta encontrada',
                  message:
                      'Nenhum nome ou e-mail corresponde à busca. '
                      'Tente outro nome ou limpe a busca.',
                ),
        ),
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
          itemCount: page.items.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) {
            final user = page.items[index];
            return AdminUserCard(
              key: ValueKey(user.id),
              user: user,
              onTap: () => _openUser(user),
            );
          },
        ),
      ),
      if (page.total > page.items.length)
        _stateSliver(
          LoadMoreNote(
            key: const Key('load-more-users'),
            message: 'Mostrando ${page.items.length} de ${page.total} contas.',
            loading: _loadingMoreUsers,
            onPressed: _loadMoreUsers,
          ),
        ),
    ];
  }

  List<Widget> _historySlivers(
    AsyncValue<AdminAccessEventPage> history,
    AccessDecisionFilter filter,
    DateTime now,
  ) {
    final controller = ref.read(accessHistoryProvider.notifier);

    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          0,
        ),
        sliver: SliverToBoxAdapter(
          child: _DecisionFilterBar(
            selected: filter,
            onSelected: ref.read(accessDecisionFilterProvider.notifier).select,
          ),
        ),
      ),
      ...switch (history) {
        AsyncData(:final value) => _eventListSlivers(value, now, filter),
        AsyncError(:final error) => [
          _stateSliver(
            AdminStateView.error(
              message: _historyFailureMessage(error),
              onRetry: controller.refresh,
            ),
          ),
        ],
        _ => [
          _stateSliver(
            const AdminStateView.loading(title: 'Carregando o histórico…'),
          ),
        ],
      },
    ];
  }

  List<Widget> _eventListSlivers(
    AdminAccessEventPage page,
    DateTime now,
    AccessDecisionFilter filter,
  ) {
    if (page.items.isEmpty) {
      return [
        _stateSliver(
          AdminStateView.empty(
            icon: Icons.history,
            title: 'Nenhum acesso encontrado',
            message: filter == AccessDecisionFilter.all
                ? 'As tentativas de acesso aparecerão aqui.'
                : 'Nenhuma tentativa corresponde a este filtro. '
                      'Toque em "Todos" para ver todas.',
          ),
        ),
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
          itemCount: page.items.length,
          separatorBuilder: (context, index) =>
              const SizedBox(height: AppSpacing.sm),
          itemBuilder: (context, index) => AccessEventCard(
            key: ValueKey(page.items[index].id),
            event: page.items[index],
            now: now,
          ),
        ),
      ),
      if (page.total > page.items.length)
        _stateSliver(
          LoadMoreNote(
            key: const Key('load-more-history'),
            message:
                'Mostrando os ${page.items.length} acessos mais recentes de '
                '${page.total}.',
            loading: _loadingMoreHistory,
            onPressed: _loadMoreHistory,
          ),
        ),
    ];
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
}

class _BackRow extends StatelessWidget {
  const _BackRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return SizedBox(
      key: const Key('back-from-admin-users'),
      height: 48,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.control),
          onTap: onTap,
          child: Row(
            children: [
              Icon(Icons.arrow_back, size: 20, color: palette.text),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  'Voltar',
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    height: 1.35,
                    color: palette.text,
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

class _Header extends StatelessWidget {
  const _Header({required this.title});

  final String title;

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
                title,
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
        ExcludeSemantics(
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

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onSelected});

  final AdminUsersTab selected;
  final ValueChanged<AdminUsersTab> onSelected;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.hairline,
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          for (final (index, tab) in AdminUsersTab.values.indexed) ...[
            if (index > 0) const SizedBox(width: 4),
            Expanded(
              child: _Segment(
                segmentKey: Key('tab-${tab.name}'),
                label: tab.label,
                selected: tab == selected,
                onTap: () => onSelected(tab),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DecisionFilterBar extends StatelessWidget {
  const _DecisionFilterBar({required this.selected, required this.onSelected});

  final AccessDecisionFilter selected;
  final ValueChanged<AccessDecisionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // Pills com largura do próprio texto: com a fonte ampliada elas quebram
    // para a linha de baixo em vez de cortar "Liberados".
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        for (final filter in AccessDecisionFilter.values)
          _FilterPill(
            key: Key('filter-${filter.name}'),
            label: filter.label,
            selected: filter == selected,
            onTap: () => onSelected(filter),
          ),
      ],
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadius.pill);

    return Semantics(
      button: true,
      container: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? palette.text : palette.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: selected ? palette.text : palette.hairline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 8,
              ),
              child: Center(
                child: Text(
                  label,
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

/// Opção de trilho segmentado: alvo de 48 dp que cresce com a fonte do
/// sistema (duas linhas em vez de cortar o rótulo).
class _Segment extends StatelessWidget {
  const _Segment({
    required this.segmentKey,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Key segmentKey;
  final String label;
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
      container: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        key: segmentKey,
        color: selected ? palette.surface : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: Center(
                child: Text(
                  label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(
                    height: 1.35,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    // Texto cheio também na opção não selecionada: o tom
                    // secundário sobre o trilho hairline fica abaixo de AA.
                    color: palette.text,
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

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onChanged;
  final Future<void> Function() onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;
    final hasText = controller.text.isNotEmpty;

    return Semantics(
      label: 'Buscar usuários',
      child: TextField(
        key: const Key('search-users-field'),
        controller: controller,
        onChanged: (_) => onChanged(),
        onSubmitted: (_) => onSubmitted(),
        textInputAction: TextInputAction.search,
        style: text.bodyLarge?.copyWith(height: 1.35),
        decoration: InputDecoration(
          hintText: 'Nome ou e-mail',
          prefixIcon: ExcludeSemantics(
            child: Icon(Icons.search, size: 20, color: palette.textSecondary),
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasText)
                IconButton(
                  key: const Key('clear-search-action'),
                  tooltip: 'Limpar busca',
                  onPressed: onClear,
                  icon: const Icon(Icons.close, size: 20),
                ),
              IconButton(
                key: const Key('submit-search-action'),
                tooltip: 'Buscar usuários',
                onPressed: () => onSubmitted(),
                icon: const Icon(Icons.arrow_forward, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.message});

  final IconData icon;
  final String message;

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
          ExcludeSemantics(
            child: Icon(icon, size: 20, color: palette.textSecondary),
          ),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(message, style: text.bodySmall?.copyWith(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

String _usersFailureMessage(Object error) {
  if (error is! AdminUsersFailure) {
    return 'Não foi possível carregar as contas. Tente novamente.';
  }
  return switch (error.reason) {
    AdminUsersFailureReason.unauthorized =>
      'Sua sessão expirou. Entre novamente.',
    AdminUsersFailureReason.forbidden =>
      'Seu perfil não pode gerenciar usuários. Peça a um administrador.',
    AdminUsersFailureReason.notFound =>
      'A conta não foi encontrada. Atualize a lista.',
    AdminUsersFailureReason.conflict =>
      'O servidor recusou a consulta de contas.',
    AdminUsersFailureReason.invalidRequest =>
      'O servidor recusou a consulta de contas.',
    AdminUsersFailureReason.unavailable =>
      'O serviço de usuários está fora do ar. Tente novamente em instantes.',
    AdminUsersFailureReason.network =>
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    AdminUsersFailureReason.timeout =>
      'O servidor demorou para responder. Tente novamente em instantes.',
    AdminUsersFailureReason.unexpected =>
      'O servidor respondeu de um jeito inesperado. Tente novamente.',
  };
}

String _historyFailureMessage(Object error) {
  if (error is! AccessEventsFailure) {
    return 'Não foi possível carregar o histórico. Tente novamente.';
  }
  return switch (error.reason) {
    AccessEventsFailureReason.unauthorized =>
      'Sua sessão expirou. Entre novamente.',
    AccessEventsFailureReason.forbidden =>
      'Seu perfil não pode ver o histórico de acessos.',
    AccessEventsFailureReason.invalidRequest =>
      'O servidor recusou a consulta do histórico.',
    AccessEventsFailureReason.unavailable =>
      'O serviço de histórico está fora do ar. Tente novamente em instantes.',
    AccessEventsFailureReason.network =>
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    AccessEventsFailureReason.timeout =>
      'O servidor demorou para responder. Tente novamente em instantes.',
    AccessEventsFailureReason.unexpected =>
      'O servidor respondeu de um jeito inesperado. Tente novamente.',
  };
}
