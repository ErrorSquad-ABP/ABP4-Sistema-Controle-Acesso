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
    baseUrl: ref.watch(apiBaseUrlProvider),
    accessToken: () => ref.read(currentSessionProvider)?.accessToken,
    onUnauthorized: (token) =>
        ref.read(sessionControllerProvider.notifier).revoke(token),
  ),
);

/// Põe o Bearer da sessão nas requisições ao backend e encerra a sessão
/// quando o backend recusa o token (401), levando o usuário de volta ao login.
/// Recusas de outras origens não afetam a sessão.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required http.Client inner,
    required String baseUrl,
    required String? Function() accessToken,
    required Future<void> Function(String accessToken) onUnauthorized,
  }) : this._(inner, Uri.tryParse(baseUrl), accessToken, onUnauthorized);

  AuthenticatedClient._(
    this._inner,
    this._origin,
    this._accessToken,
    this._onUnauthorized,
  );

  final http.Client _inner;
  final Uri? _origin;
  final String? Function() _accessToken;
  final Future<void> Function(String accessToken) _onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = _accessToken();
    if (token == null) throw const AuthFailure(AuthFailureReason.unauthorized);
    // Só a origem do backend recebe o Bearer: o mesmo cliente pode atender
    // links e imagens de terceiros.
    final isBackend = _isBackend(request.url);
    if (isBackend) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await _inner.send(request);
    // 401 de terceiros não diz nada sobre o nosso token.
    if (isBackend && response.statusCode == 401) {
      unawaited(_onUnauthorized(token));
    }
    return response;
  }

  bool _isBackend(Uri url) {
    final origin = _origin;
    return origin != null &&
        url.scheme == origin.scheme &&
        url.host == origin.host &&
        url.port == origin.port;
  }

  /// O cliente interno é compartilhado e fechado pelo `httpClientProvider`.
  @override
  void close() {}
}
