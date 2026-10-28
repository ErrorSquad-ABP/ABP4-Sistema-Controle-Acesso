import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_contract.dart';

/// Onde a sessão sobrevive ao fechamento do app.
abstract interface class SessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  Future<void> clear();
}

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(FlutterSecureStorage()),
);

/// Guarda a sessão no Keystore (Android) via `flutter_secure_storage`.
/// A senha nunca é gravada: só o JWT, a validade e o usuário.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._storage);

  static const String key = 'auth.session.v1';

  final FlutterSecureStorage _storage;

  @override
  Future<AuthSession?> read() async {
    try {
      final raw = await _storage.read(key: key);
      if (raw == null) return null;
      return AuthSession.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (error) {
      // Valor corrompido ou cofre ilegível (ex.: chave do Keystore perdida):
      // descarta e pede login de novo em vez de travar a abertura do app.
      debugPrint('Sessao local descartada: ${error.runtimeType}');
      await _clearQuietly();
      return null;
    }
  }

  @override
  Future<void> write(AuthSession session) =>
      _storage.write(key: key, value: jsonEncode(session.toJson()));

  @override
  Future<void> clear() => _storage.delete(key: key);

  Future<void> _clearQuietly() async {
    try {
      await clear();
    } catch (_) {}
  }
}
