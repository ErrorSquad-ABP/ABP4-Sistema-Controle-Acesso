import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/login_page.dart';
import '../../features/home/home_page.dart';
import '../../features/scanner/scanner_page.dart';

/// Caminhos das rotas do app. Cada feature registra a sua aqui.
abstract final class AppRoutes {
  static const String home = '/';
  static const String login = '/login';
  static const String scan = '/scan';
}

/// Router unico do app, exposto via Riverpod para que redirects futuros
/// (ex.: sessao de login) possam observar outros providers.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: AppRoutes.login,
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.scan,
        builder: (context, state) => const ScannerPage(),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
