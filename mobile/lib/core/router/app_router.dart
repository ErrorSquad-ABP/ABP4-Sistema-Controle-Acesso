import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/shell/app_shell.dart';
import '../../features/admin_authorizations/admin_authorizations_page.dart';
import '../../features/admin_users/admin_users_page.dart';
import '../../features/auth/login_page.dart';
import '../../features/auth/session_controller.dart';
import '../../features/auth/session_loading_page.dart';
import '../../features/authorizations/authorization_contract.dart';
import '../../features/authorizations/authorization_detail_page.dart';
import '../../features/authorizations/authorizations_page.dart';
import '../../features/locations/locations_page.dart';
import '../../features/profile/profile_page.dart';
import '../../features/scanner/scanner_page.dart';

/// Caminhos das rotas do app. Cada feature registra a sua aqui.
abstract final class AppRoutes {
  /// Aba Autorizações: a tela principal depois do login.
  static const String home = '/';
  static const String history = '/historico';
  static const String profile = '/perfil';
  static const String login = '/login';
  static const String loading = '/loading';
  static const String scan = '/scan';

  /// Detalhe de uma autorização, aberto pelo cartão da lista.
  static const String authorizationDetailPattern = '/autorizacoes/:id';
  static String authorizationDetail(String id) =>
      '/autorizacoes/${Uri.encodeComponent(id)}';

  /// Administração de locais: aberta a partir do Perfil.
  static const String locations = '/locais';
  /// Administração de autorizações (US-30).
  static const String adminAuthorizations = '/admin/autorizacoes';
  /// Administração de usuários e histórico (US-31).
  static const String adminUsers = '/admin/usuarios';
}

/// Guarda de sessão: restaurando → abertura; deslogado → login; logado fora
/// das telas públicas. Rotas novas ficam protegidas sem configuração extra.
@visibleForTesting
String? sessionRedirect(AsyncValue<SessionState> session, String location) {
  if (session.isLoading && !session.hasValue) {
    return location == AppRoutes.loading ? null : AppRoutes.loading;
  }
  // Erro ao restaurar conta como deslogado.
  if (session.value?.session == null) {
    return location == AppRoutes.login ? null : AppRoutes.login;
  }
  if (location == AppRoutes.login || location == AppRoutes.loading) {
    return AppRoutes.home;
  }
  return null;
}

/// Router unico do app. Nao observa a sessao com `watch` (recriaria o
/// router): repassa as mudancas ao `refreshListenable`, que reavalia o
/// redirect.
final appRouterProvider = Provider<GoRouter>((ref) {
  final session = ValueNotifier(ref.read(sessionControllerProvider));
  ref.listen(sessionControllerProvider, (_, next) => session.value = next);

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: session,
    redirect: (context, state) =>
        sessionRedirect(session.value, state.matchedLocation),
    routes: [
      GoRoute(
        path: AppRoutes.loading,
        builder: (context, state) => const SessionLoadingPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      // As três abas mantêm o próprio estado ao alternar.
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const AuthorizationsPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.history,
                builder: (context, state) => const AuthorizationsPage(
                  initialFilter: AuthorizationFilter.history,
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.profile,
                builder: (context, state) => const ProfilePage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScannerPage(),
      ),
      GoRoute(
        path: AppRoutes.authorizationDetailPattern,
        builder: (context, state) =>
            AuthorizationDetailPage(id: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.locations,
        builder: (context, state) => const LocationsPage(),
      ),
      GoRoute(
        path: AppRoutes.adminAuthorizations,
        builder: (context, state) => const AdminAuthorizationsPage(),
      ),
      GoRoute(
        path: AppRoutes.adminUsers,
        builder: (context, state) => const AdminUsersPage(),
      ),
    ],
  );
  ref.onDispose(() {
    router.dispose();
    session.dispose();
  });
  return router;
});
