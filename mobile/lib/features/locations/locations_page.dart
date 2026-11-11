import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import '../auth/auth_contract.dart';
import '../auth/session_controller.dart';
import 'location_card.dart';
import 'location_contract.dart';
import 'location_state_view.dart';
import 'locations_controller.dart';
import 'new_location_page.dart';

/// Tela "Locais de acesso" (frame Claro 77:154 / Escuro 77:241): cabeçalho,
/// lista dos locais ativos e a ação de cadastrar, só para ADMIN.
class LocationsPage extends ConsumerStatefulWidget {
  const LocationsPage({super.key});

  @override
  ConsumerState<LocationsPage> createState() => _LocationsPageState();
}

class _LocationsPageState extends ConsumerState<LocationsPage> {
  Future<void> _openForm() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(builder: (context) => const NewLocationPage()),
    );
    // O formulário devolve true quando o local foi criado.
    if (created == true && mounted) {
      await ref.read(locationsProvider.notifier).refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = ref.watch(locationsProvider);
    final isAdmin =
        ref.watch(currentSessionProvider)?.user.role == UserRole.admin;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screen,
                AppSpacing.sm,
                AppSpacing.screen,
                0,
              ),
              child: _Header(),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: switch (page) {
                AsyncData(:final value) => _LocationList(
                  locations: value.items,
                  onRefresh: ref.read(locationsProvider.notifier).refresh,
                ),
                AsyncError(:final error) => _StateScroll(
                  child: LocationStateView.error(
                    message: _listFailureMessage(error),
                    onRetry: ref.read(locationsProvider.notifier).refresh,
                  ),
                ),
                _ => const _StateScroll(child: LocationStateView.loading()),
              },
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
                      _NewLocationAction(
                        onPressed: _openForm,
                      )
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
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Row(
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
                'Locais de acesso',
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

class _LocationList extends StatelessWidget {
  const _LocationList({required this.locations, required this.onRefresh});

  final List<Location> locations;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    if (locations.isEmpty) {
      return RefreshIndicator(
        onRefresh: onRefresh,
        color: palette.text,
        backgroundColor: palette.surface,
        child: const _StateScroll(child: LocationStateView.empty()),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: palette.text,
      backgroundColor: palette.surface,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screen,
          AppSpacing.sm,
          AppSpacing.screen,
          AppSpacing.xs,
        ),
        itemCount: locations.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSpacing.sm),
        itemBuilder: (context, index) => LocationCard(
          key: ValueKey(locations[index].id),
          location: locations[index],
        ),
      ),
    );
  }
}

/// Área rolável dos estados: com fonte ampliada o cartão cresce e precisa
/// rolar em vez de estourar.
class _StateScroll extends StatelessWidget {
  const _StateScroll({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screen,
        AppSpacing.sm,
        AppSpacing.screen,
        AppSpacing.xs,
      ),
      children: [child],
    );
  }
}

class _NewLocationAction extends StatelessWidget {
  const _NewLocationAction({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      label: 'Novo local',
      child: SizedBox(
        key: const Key('new-location-action'),
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
                      'Novo local',
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
                      child: Icon(
                        Icons.add,
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
      ),
    );
  }
}

/// A API só aceita `POST /locations` de ADMIN (403 para os demais perfis):
/// em vez de esconder o motivo, a tela explica por que não há ação.
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
              'Só administradores cadastram locais. Peça a um administrador '
              'para incluir um novo ponto de acesso.',
              style: text.bodySmall?.copyWith(height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

String _listFailureMessage(Object error) {
  if (error is! LocationFailure) {
    return 'Não foi possível carregar os locais. Tente novamente.';
  }
  return switch (error.reason) {
    LocationFailureReason.unauthorized =>
      'Sua sessão expirou. Entre novamente.',
    LocationFailureReason.forbidden => 'Seu perfil não pode consultar os locais.',
    LocationFailureReason.invalidRequest =>
      'O servidor recusou a consulta de locais.',
    LocationFailureReason.unavailable =>
      'O serviço de locais está fora do ar. Tente novamente em instantes.',
    LocationFailureReason.network =>
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
    LocationFailureReason.timeout =>
      'O servidor demorou para responder. Tente novamente em instantes.',
    LocationFailureReason.unexpected =>
      'O servidor respondeu de um jeito inesperado. Tente novamente.',
  };
}
