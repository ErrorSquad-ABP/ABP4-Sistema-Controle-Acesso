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

  Future<AdminAccessEventPage> _fetch(AccessDecisionFilter filter) => ref
      .read(accessEventsGatewayProvider)
      .list(decision: filter.decision, pageSize: accessHistoryPageSize);

  Future<void> refresh() async {
    final filter = ref.read(accessDecisionFilterProvider);
    state = await AsyncValue.guard(() => _fetch(filter));
  }
}
