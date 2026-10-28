import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import 'auth_contract.dart';
import 'session_controller.dart';

/// Cliente das rotas protegidas (US-28, US-29, admin): use no lugar do
/// `httpClientProvider` sempre que a rota exigir login.
final authenticatedClientProvider = Provider<http.Client>(
  (ref) => AuthenticatedClient(
    inner: ref.watch(httpClientProvider),
    accessToken: () => ref.read(currentSessionProvider)?.accessToken,
    onUnauthorized: (token) =>
        ref.read(sessionControllerProvider.notifier).revoke(token),
  ),
);

/// Põe o Bearer da sessão em cada requisição e encerra a sessão quando o
/// backend recusa o token (401), levando o usuário de volta ao login.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required http.Client inner,
    required String? Function() accessToken,
    required Future<void> Function(String accessToken) onUnauthorized,
  }) : this._(inner, accessToken, onUnauthorized);

  AuthenticatedClient._(this._inner, this._accessToken, this._onUnauthorized);

  final http.Client _inner;
  final String? Function() _accessToken;
  final Future<void> Function(String accessToken) _onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = _accessToken();
    if (token == null) throw const AuthFailure(AuthFailureReason.unauthorized);
    request.headers['Authorization'] = 'Bearer $token';
    final response = await _inner.send(request);
    if (response.statusCode == 401) unawaited(_onUnauthorized(token));
    return response;
  }

  /// O cliente interno é compartilhado e fechado pelo `httpClientProvider`.
  @override
  void close() {}
}
