import 'dart:async';

import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/http_auth_gateway.dart';
import 'package:controle_acesso/features/auth/session_store.dart';
// Override é exportado só pelo pacote misc no Riverpod 3.
import 'package:flutter_riverpod/misc.dart' show Override;

final fixedNow = DateTime.utc(2026, 10, 27, 12);

const maria = AuthUser(
  id: '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  name: 'Maria Souza',
  email: 'maria.souza@exemplo.com',
  role: UserRole.resident,
);

AuthSession sessionFor({
  AuthUser user = maria,
  Duration validFor = const Duration(hours: 1),
  String token = 'jwt-maria',
}) => AuthSession(
  accessToken: token,
  expiresAt: fixedNow.add(validFor),
  user: user,
);

class InMemorySessionStore implements SessionStore {
  InMemorySessionStore([this.session]);

  AuthSession? session;

  /// Simulam o Keystore indisponível.
  bool failWrite = false;
  bool failClear = false;

  /// Quando definido, a leitura só responde ao completar este completer.
  Completer<void>? readGate;

  /// Quando definido, o `clear` só responde ao completar este completer.
  Completer<void>? clearGate;

  @override
  Future<AuthSession?> read() async {
    await readGate?.future;
    return session;
  }

  @override
  Future<void> write(AuthSession session) async {
    if (failWrite) throw Exception('keystore');
    this.session = session;
  }

  @override
  Future<void> clear() async {
    await clearGate?.future;
    if (failClear) throw Exception('keystore');
    session = null;
  }
}

/// Relógio que o teste avança.
class FakeClock {
  DateTime now = fixedNow;

  void advance(Duration by) => now = now.add(by);
}

class FakeAuthGateway implements AuthGateway {
  FakeAuthGateway({this.loginFailure, this.meFailure});

  AuthFailureReason? loginFailure;
  AuthFailureReason? meFailure;
  AuthUser meUser = maria;

  /// Quando definidos, login e `/auth/me` só respondem ao completar o
  /// completer.
  Completer<void>? loginGate;
  Completer<void>? meGate;

  final List<LoginRequest> logins = [];
  final List<String> meTokens = [];

  @override
  Future<AuthSession> login(LoginRequest request) async {
    logins.add(request);
    await loginGate?.future;
    if (loginFailure != null) throw AuthFailure(loginFailure!);
    return sessionFor();
  }

  @override
  Future<AuthUser> currentUser(String accessToken) async {
    meTokens.add(accessToken);
    await meGate?.future;
    if (meFailure != null) throw AuthFailure(meFailure!);
    return meUser;
  }
}

List<Override> authOverrides({
  FakeAuthGateway? gateway,
  SessionStore? store,
  FakeClock? clock,
}) => [
  authGatewayProvider.overrideWithValue(gateway ?? FakeAuthGateway()),
  sessionStoreProvider.overrideWithValue(store ?? InMemorySessionStore()),
  clockProvider.overrideWithValue(
    clock == null ? () => fixedNow : () => clock.now,
  ),
];
