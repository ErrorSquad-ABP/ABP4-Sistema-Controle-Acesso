import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'authorization_contract.dart';
import 'http_authorization_gateway.dart';

/// Autorizações do usuário logado. Compartilhada pelas abas do shell: o
/// Histórico é o mesmo recorte da lista, só com outro filtro.
final myAuthorizationsProvider =
    AsyncNotifierProvider<MyAuthorizationsController, AuthorizationPage>(
      MyAuthorizationsController.new,
    );

class MyAuthorizationsController extends AsyncNotifier<AuthorizationPage> {
  @override
  Future<AuthorizationPage> build() async {
    // Trocar de conta zera a lista: o dado de um usuário não aparece no outro.
    if (ref.watch(currentSessionProvider) == null) {
      return const AuthorizationPage(items: [], page: 1, pageSize: 0, total: 0);
    }
    return _fetch();
  }

  Future<AuthorizationPage> _fetch() =>
      ref.read(authorizationGatewayProvider).listMine();

  /// Pull-to-refresh e "Tentar novamente" mantêm a lista atual na tela
  /// enquanto buscam de novo.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}

/// Autorização aberta pelo cartão da lista. Auto-dispose: sair do detalhe
/// libera o dado; voltar refaz a consulta.
final authorizationDetailProvider = FutureProvider.autoDispose
    .family<Authorization, String>(
      (ref, id) => ref.read(authorizationGatewayProvider).findById(id),
    );
