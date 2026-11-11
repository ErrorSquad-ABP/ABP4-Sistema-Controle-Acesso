import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import 'authorization_contract.dart';

/// Uma página por vez; a tela pede a primeira com o maior tamanho aceito.
/// `GET /me/authorizations` não tem UI de paginação no design.
const int _pageSize = 100;

final authorizationGatewayProvider = Provider<AuthorizationGateway>(
  (ref) => HttpAuthorizationGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class HttpAuthorizationGateway implements AuthorizationGateway {
  HttpAuthorizationGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpAuthorizationGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<AuthorizationPage> listMine({
    int page = 1,
    int pageSize = _pageSize,
  }) async {
    final http.Response response;
    try {
      final uri = Uri.parse('$_baseUrl/api/v1/me/authorizations')
          .replace(queryParameters: {'page': '$page', 'pageSize': '$pageSize'});
      response = await _client
          .get(uri, headers: const {'Accept': 'application/json'})
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthorizationFailure(AuthorizationFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw AuthorizationFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? AuthorizationFailureReason.unauthorized
            : AuthorizationFailureReason.network,
      );
    } on http.ClientException {
      throw const AuthorizationFailure(AuthorizationFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AuthorizationFailure(AuthorizationFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const AuthorizationFailure(AuthorizationFailureReason.network);
    }

    final status = response.statusCode;
    if (status == 200) {
      try {
        return AuthorizationPage.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        );
      } on FormatException {
        throw const AuthorizationFailure(AuthorizationFailureReason.unexpected);
      } on TypeError {
        throw const AuthorizationFailure(AuthorizationFailureReason.unexpected);
      }
    }
    throw AuthorizationFailure(switch (status) {
      401 => AuthorizationFailureReason.unauthorized,
      429 || >= 500 => AuthorizationFailureReason.unavailable,
      _ => AuthorizationFailureReason.unexpected,
    });
  }
}
