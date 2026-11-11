import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_contract.dart';
import '../auth/http_auth_gateway.dart';
import '../auth/session_controller.dart';
import '../auth/session_store.dart';
import 'http_profile_gateway.dart';

/// Usuário exibido no Perfil. Nasce do usuário da sessão, que o app já validou
/// em `GET /auth/me` na abertura, e acompanha refresh e edição do nome.
final profileUserProvider = NotifierProvider<ProfileController, AuthUser?>(
  ProfileController.new,
);

class ProfileController extends Notifier<AuthUser?> {
  @override
  AuthUser? build() => ref.watch(currentSessionProvider)?.user;

  /// Reconsulta `GET /auth/me`. Em falha mantém o dado atual e repassa o erro
  /// para a tela avisar sem apagar o perfil. O 401 encerra a sessão aqui
  /// mesmo: o router leva ao login e o cofre local é limpo.
  Future<void> refresh() async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    final AuthUser user;
    try {
      user = await ref
          .read(authGatewayProvider)
          .currentUser(session.accessToken);
    } on AuthFailure catch (failure) {
      if (failure.reason == AuthFailureReason.unauthorized) {
        await ref
            .read(sessionControllerProvider.notifier)
            .revoke(session.accessToken);
      }
      rethrow;
    }
    if (!ref.mounted) return;
    state = user;
    await _remember(user);
  }

  /// `PATCH /me`. Erros sobem como [AuthFailure] para o diálogo explicar.
  Future<void> rename(String name) async {
    final user = await ref.read(profileGatewayProvider).updateName(name);
    if (!ref.mounted) return;
    state = user;
    await _remember(user);
  }

  /// Mantém o nome do cofre em dia. Falhar aqui só custa o nome antigo até a
  /// próxima revalidação da sessão.
  Future<void> _remember(AuthUser user) async {
    final session = ref.read(currentSessionProvider);
    if (session == null) return;
    try {
      await ref.read(sessionStoreProvider).write(session.withUser(user));
    } catch (error) {
      debugPrint('Perfil nao persistido: ${error.runtimeType}');
    }
  }
}
