import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'access_events_contract.dart';
import 'http_access_events_gateway.dart';

/// Maior página aceita por `GET /access-events`.
const int accessHistoryPageSize = 100;

/// Filtro da aba Histórico. Trocar o filtro refaz a consulta com o parâmetro
/// `decision`; `Todos` não envia o parâmetro.
final accessDecisionFilterProvider =
    NotifierProvider<AccessDecisionFilterController, AccessDecisionFilter>(
      AccessDecisionFilterController.new,
    );

class AccessDecisionFilterController extends Notifier<AccessDecisionFilter> {
  @override
  AccessDecisionFilter build() => AccessDecisionFilter.all;

  void select(AccessDecisionFilter filter) {
    if (filter == state) return;
    state = filter;
  }
}

/// Tentativas de acesso do condomínio, da mais recente para a mais antiga.
final accessHistoryProvider =
    AsyncNotifierProvider<AccessHistoryController, AdminAccessEventPage>(
      AccessHistoryController.new,
    );

class AccessHistoryController extends AsyncNotifier<AdminAccessEventPage> {
  @override
  Future<AdminAccessEventPage> build() async {
    // Trocar de conta zera o histórico: o dado de um usuário não aparece no outro.
    if (ref.watch(currentSessionProvider) == null) {
      return const AdminAccessEventPage(
        items: [],
        page: 1,
        pageSize: 0,
        total: 0,
      );
    }
    return _fetch(ref.watch(accessDecisionFilterProvider));
  }

  Future<AdminAccessEventPage> _fetch(
    AccessDecisionFilter filter, {
    int page = 1,
  }) => ref
      .read(accessEventsGatewayProvider)
      .list(
        decision: filter.decision,
        page: page,
        pageSize: accessHistoryPageSize,
      );

  Future<void> refresh() async {
    final filter = ref.read(accessDecisionFilterProvider);
    state = await AsyncValue.guard(() => _fetch(filter));
  }

  /// Busca a página seguinte do mesmo recorte e anexa ao histórico na tela.
  /// Se falhar, o que já foi carregado continua visível.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || current.items.length >= current.total) return;
    final next = await _fetch(
      ref.read(accessDecisionFilterProvider),
      page: current.page + 1,
    );
    // Filtro trocado, lista recarregada ou sessão encerrada enquanto buscava.
    if (!ref.mounted || !identical(state.value, current)) return;
    final seen = {for (final event in current.items) event.id};
    state = AsyncData(
      AdminAccessEventPage(
        items: [
          ...current.items,
          for (final event in next.items)
            if (seen.add(event.id)) event,
        ],
        page: next.page,
        pageSize: next.pageSize,
        total: next.total,
      ),
    );
  }
}
