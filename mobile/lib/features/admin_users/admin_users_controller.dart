import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'admin_users_contract.dart';
import 'http_admin_users_gateway.dart';

/// Maior página aceita por `GET /users`.
const int adminUsersPageSize = 100;

/// Termo da busca da lista. Separado da lista porque a tela só envia a busca
/// quando a pessoa confirma (botão ou teclado), não a cada tecla.
final adminUsersSearchProvider =
    NotifierProvider<AdminUsersSearchController, String>(
      AdminUsersSearchController.new,
    );

class AdminUsersSearchController extends Notifier<String> {
  @override
  String build() => '';

  void search(String value) => state = value.trim();
}

/// Contas do condomínio, em ordem alfabética (a API ordena).
final adminUsersProvider =
    AsyncNotifierProvider<AdminUsersController, AdminUserPage>(
      AdminUsersController.new,
    );

class AdminUsersController extends AsyncNotifier<AdminUserPage> {
  @override
  Future<AdminUserPage> build() async {
    // Trocar de conta zera a lista: o dado de um usuário não aparece no outro.
    if (ref.watch(currentSessionProvider) == null) {
      return const AdminUserPage(items: [], page: 1, pageSize: 0, total: 0);
    }
    return _fetch(ref.watch(adminUsersSearchProvider));
  }

  Future<AdminUserPage> _fetch(String search) => ref
      .read(adminUsersGatewayProvider)
      .list(search: search, pageSize: adminUsersPageSize);

  /// Pull-to-refresh, "Tentar novamente" e a volta do formulário mantêm a
  /// lista atual na tela enquanto buscam de novo.
  Future<void> refresh() async {
    final search = ref.read(adminUsersSearchProvider);
    state = await AsyncValue.guard(() => _fetch(search));
  }
}

/// Conta aberta pelo cartão da lista. Auto-dispose: sair da tela libera o
/// dado; voltar refaz a consulta.
final adminUserDetailProvider = FutureProvider.autoDispose
    .family<AdminUser, String>(
      (ref, id) => ref.read(adminUsersGatewayProvider).findById(id),
    );
