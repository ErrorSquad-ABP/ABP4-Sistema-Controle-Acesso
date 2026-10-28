import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_contract.dart';
import 'http_auth_gateway.dart';
import 'session_store.dart';

/// Sessão do app: `AsyncLoading` enquanto restaura, `null` deslogado.
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, AuthSession?>(
      SessionController.new,
    );

class SessionController extends AsyncNotifier<AuthSession?> {
  Timer? _expiry;

  SessionStore get _store => ref.read(sessionStoreProvider);
  AuthGateway get _gateway => ref.read(authGatewayProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<AuthSession?> build() async {
    ref.onDispose(() => _expiry?.cancel());
    try {
      return _activate(await _restore());
    } catch (_) {
      // Falha inesperada ao restaurar não pode prender o app na abertura.
      return null;
    }
  }

  /// Autentica e persiste. Falhas sobem como [AuthFailure] para a tela.
  Future<void> login(LoginRequest request) async {
    final session = await _gateway.login(request);
    await _store.write(session);
    if (!ref.mounted) return;
    state = AsyncData(_activate(session));
  }

  /// Encerra a sessão local. O JWT é stateless: não há logout no backend.
  Future<void> logout() async {
    _expiry?.cancel();
    await _store.clear();
    if (!ref.mounted) return;
    state = const AsyncData(null);
  }

  Future<AuthSession?> _restore() async {
    final stored = await _store.read();
    if (stored == null) return null;
    if (stored.isExpiredAt(_now())) {
      await _store.clear();
      return null;
    }
    try {
      // Confere no backend: usuário desativado ou token revogado cai aqui.
      final user = await _gateway.currentUser(stored.accessToken);
      final refreshed = stored.withUser(user);
      await _store.write(refreshed);
      return refreshed;
    } on AuthFailure catch (failure) {
      if (failure.reason == AuthFailureReason.unauthorized) {
        await _store.clear();
        return null;
      }
      // Sem rede ou backend fora: mantém a sessão até o token vencer.
      return stored;
    }
  }

  /// Agenda a saída automática para quando o token vencer.
  AuthSession? _activate(AuthSession? session) {
    _expiry?.cancel();
    if (session == null) return null;
    final remaining = session.expiresAt
        .subtract(AuthSession.expirySkew)
        .difference(_now().toUtc());
    _expiry = Timer(remaining.isNegative ? Duration.zero : remaining, logout);
    return session;
  }
}
