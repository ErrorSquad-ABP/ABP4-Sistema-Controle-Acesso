import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_contract.dart';

/// Onde a sessão sobrevive ao fechamento do app.
abstract interface class SessionStore {
  Future<AuthSession?> read();

  Future<void> write(AuthSession session);

  /// Invalida a sessão salva. Lança quando o cofre não confirma a exclusão
  /// nem deixa um valor que a leitura descarte.
  Future<void> clear();
}

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => const SecureSessionStore(FlutterSessionVault()),
);

/// Operações do cofre que a sessão usa. Existe para os testes simularem um
/// Keystore que falha ao gravar ou apagar.
abstract interface class SessionVault {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);

  Future<void> deleteAll();
}

/// Adaptador do `flutter_secure_storage` (Keystore no Android).
class FlutterSessionVault implements SessionVault {
  const FlutterSessionVault([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

/// Guarda a sessão no Keystore via `flutter_secure_storage`.
/// A senha nunca é gravada: só o JWT, a validade e o usuário.
class SecureSessionStore implements SessionStore {
  const SecureSessionStore(this._vault);

  static const String key = 'auth.session.v1';

  final SessionVault _vault;

  @override
  Future<AuthSession?> read() async {
    try {
      final raw = await _vault.read(key);
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
      _vault.write(key, jsonEncode(session.toJson()));

  @override
  Future<void> clear() async {
    // Fase 1: sobrescrever com um valor que a leitura descarta. Se o delete
    // falhar depois, a sessão ainda assim não volta ao reabrir o app.
    try {
      await _vault.write(key, '');
    } catch (_) {
      // Fase 2: sem gravar, apagar resolve; se nem isso funcionar, `deleteAll`
      // é o último recurso antes de avisar quem chamou.
      try {
        await _vault.delete(key);
        return;
      } catch (_) {
        try {
          await _vault.deleteAll();
          return;
        } catch (_) {
          throw Exception('Sessao local nao invalidada');
        }
      }
    }
    try {
      await _vault.delete(key);
    } catch (error) {
      debugPrint('Sessao local invalidada sem apagar: ${error.runtimeType}');
    }
  }

  Future<void> _clearQuietly() async {
    try {
      await clear();
    } catch (_) {}
  }
}
