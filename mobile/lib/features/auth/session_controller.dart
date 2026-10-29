import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/clock.dart';
import 'auth_contract.dart';
import 'http_auth_gateway.dart';
import 'session_store.dart';

enum SessionEndReason {
  /// O token venceu.
  expired,

  /// O backend recusou o token (401): usuário desativado ou token inválido.
  revoked,

  /// A sessão saiu do app, mas o cofre não confirmou a exclusão: o token
  /// pode voltar se o app for reaberto.
  notErased,
}

/// Por que a sessão anterior acabou sem o usuário pedir; vira aviso no login.
class SessionEnd {
  const SessionEnd(this.reason, this.email);

  final SessionEndReason reason;
  final String email;
}

class SessionState {
  const SessionState.signedIn(AuthSession this.session) : ended = null;

  const SessionState.signedOut([this.ended]) : session = null;

  final AuthSession? session;

  /// Só preenchido quando a saída não foi pedida pelo usuário.
  final SessionEnd? ended;
}

/// Sessão do app: `AsyncLoading` enquanto restaura a sessão salva.
final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );

/// Sessão ativa, ou `null` (deslogado ou ainda restaurando).
final currentSessionProvider = Provider<AuthSession?>(
  (ref) => ref.watch(sessionControllerProvider).value?.session,
);

class SessionController extends AsyncNotifier<SessionState> {
  Timer? _expiry;

  SessionStore get _store => ref.read(sessionStoreProvider);
  AuthGateway get _gateway => ref.read(authGatewayProvider);
  DateTime _now() => ref.read(clockProvider)();

  @override
  Future<SessionState> build() async {
    // O timer não avança com o aparelho suspenso: confere de novo na volta.
    final lifecycle = AppLifecycleListener(onResume: _checkExpiry);
    ref.onDispose(() {
      _expiry?.cancel();
      lifecycle.dispose();
    });
    try {
      return _activate(await _restore());
    } catch (_) {
      // Falha inesperada ao restaurar não pode prender o app na abertura.
      return const SessionState.signedOut();
    }
  }

  /// Autentica e persiste. Falhas de autenticação sobem como [AuthFailure].
  Future<void> login(LoginRequest request) async {
    final session = await _gateway.login(request);
    try {
      await _store.write(session);
    } catch (error) {
      // Credencial aceita: entra mesmo sem persistir; só não sobrevive ao
      // fechamento do app.
      debugPrint('Sessao nao persistida: ${error.runtimeType}');
    }
    if (!ref.mounted) return;
    state = AsyncData(_activate(SessionState.signedIn(session)));
  }

  /// Saída pedida pelo usuário. O JWT é stateless: não há logout no backend.
  Future<void> logout() => _end(null);

  /// O backend recusou [accessToken]. Ignora o token de uma sessão que já
  /// foi trocada por outra.
  Future<void> revoke(String accessToken) async {
    if (state.value?.session?.accessToken != accessToken) return;
    await _end(SessionEndReason.revoked);
  }

  /// Tira o aviso da sessão anterior (nova tentativa de login).
  void dismissNotice() {
    if (state.value?.ended == null) return;
    state = const AsyncData(SessionState.signedOut());
  }

  Future<SessionState> _restore() async {
    final stored = await _store.read();
    if (stored == null) return const SessionState.signedOut();
    if (stored.isExpiredAt(_now())) {
      await _clearStore();
      return SessionState.signedOut(
        SessionEnd(SessionEndReason.expired, stored.user.email),
      );
    }
    // Abre com a sessão salva e confere no backend em segundo plano: a
    // abertura não espera a rede (sinal fraco, partida a frio da Vercel).
    unawaited(_revalidate(stored));
    return SessionState.signedIn(stored);
  }

  /// Confere a sessão restaurada em `GET /auth/me` e atualiza o usuário.
  /// Só o 401 (usuário desativado ou token recusado) encerra a sessão; sem
  /// rede, TLS recusado ou backend fora, ela vale até o token vencer.
  Future<void> _revalidate(AuthSession stored) async {
    // Espera o build entregar a sessão restaurada ao estado.
    await future;
    final AuthUser user;
    try {
      user = await _gateway.currentUser(stored.accessToken);
    } on AuthFailure catch (failure) {
      if (failure.reason == AuthFailureReason.unauthorized && ref.mounted) {
        await revoke(stored.accessToken);
      }
      return;
    } catch (error) {
      debugPrint('Sessao mantida sem conferir: ${error.runtimeType}');
      return;
    }
    // Saiu ou trocou de sessão enquanto conferia.
    if (!ref.mounted ||
        state.value?.session?.accessToken != stored.accessToken) {
      return;
    }
    final refreshed = stored.withUser(user);
    state = AsyncData(SessionState.signedIn(refreshed));
    try {
      await _store.write(refreshed);
    } catch (error) {
      debugPrint('Sessao nao atualizada: ${error.runtimeType}');
    }
  }

  Future<void> _end(SessionEndReason? reason) async {
    _expiry?.cancel();
    final session = state.value?.session;
    // Estado primeiro: falha do armazenamento não pode manter ninguém logado.
    state = AsyncData(
      SessionState.signedOut(
        reason == null || session == null
            ? null
            : SessionEnd(reason, session.user.email),
      ),
    );
    final erased = await _clearStore();
    if (erased || !ref.mounted || session == null) return;
    final current = state.value;
    // Já voltou a logar (ou já há um motivo de saída mais urgente).
    if (current?.session != null || current?.ended != null) return;
    state = AsyncData(
      SessionState.signedOut(
        SessionEnd(SessionEndReason.notErased, session.user.email),
      ),
    );
  }

  Future<bool> _clearStore() async {
    try {
      await _store.clear();
      return true;
    } catch (error) {
      debugPrint('Sessao local nao apagada: ${error.runtimeType}');
      return false;
    }
  }

  void _checkExpiry() {
    final current = state.value;
    final session = current?.session;
    if (session == null) return;
    if (session.isExpiredAt(_now())) {
      unawaited(_end(SessionEndReason.expired));
    } else {
      _activate(current!);
    }
  }

  /// Agenda a saída automática para quando o token vencer.
  SessionState _activate(SessionState next) {
    _expiry?.cancel();
    final session = next.session;
    if (session == null) return next;
    final remaining = session.expiresAt
        .subtract(AuthSession.expirySkew)
        .difference(_now().toUtc());
    _expiry = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      () => unawaited(_end(SessionEndReason.expired)),
    );
    return next;
  }
}
