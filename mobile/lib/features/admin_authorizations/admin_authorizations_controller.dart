import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import '../authorizations/authorization_contract.dart';
import 'admin_authorization_contract.dart';
import 'http_admin_authorization_gateway.dart';

/// Autorizações de todos os moradores, para o ADMIN (US-30). A situação é
/// filtrada pelo servidor (`status` de `GET /authorizations`); a busca por
/// texto é local, porque o endpoint não aceita `search`.
final adminAuthorizationsProvider =
    AsyncNotifierProvider<AdminAuthorizationsController, AuthorizationPage>(
      AdminAuthorizationsController.new,
    );

class AdminAuthorizationsController extends AsyncNotifier<AuthorizationPage> {
  AdminAuthorizationFilter _filter = AdminAuthorizationFilter.all;

  @override
  Future<AuthorizationPage> build() async {
    // Trocar de conta zera a lista: o dado de um usuário não aparece no outro.
    if (ref.watch(currentSessionProvider) == null) {
      return const AuthorizationPage(items: [], page: 1, pageSize: 0, total: 0);
    }
    return _fetch();
  }

  Future<AuthorizationPage> _fetch() =>
      ref.read(adminAuthorizationGatewayProvider).list(status: _filter.status);

  /// Troca o recorte de situação e busca de novo no servidor.
  Future<void> setFilter(AdminAuthorizationFilter filter) async {
    if (filter == _filter) return;
    _filter = filter;
    state = const AsyncLoading();
    state = await AsyncValue.guard(_fetch);
  }

  /// Pull-to-refresh, "Tentar novamente" e depois de criar ou cancelar.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}
