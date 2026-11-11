import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';

final profileGatewayProvider = Provider<ProfileGateway>(
  (ref) => HttpProfileGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

/// Edição do próprio perfil (`PATCH /me` do contrato v1).
abstract interface class ProfileGateway {
  /// Só o nome é editável; o resto do usuário volta igual ao `GET /auth/me`.
  Future<AuthUser> updateName(String name);
}

class HttpProfileGateway implements ProfileGateway {
  HttpProfileGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpProfileGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<AuthUser> updateName(String name) async {
    final http.Response response;
    try {
      response = await _client
          .patch(
            Uri.parse('$_baseUrl/api/v1/me'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'name': name}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw AuthFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? AuthFailureReason.unauthorized
            : AuthFailureReason.network,
      );
    } on http.ClientException {
      throw const AuthFailure(AuthFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AuthFailure(AuthFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const AuthFailure(AuthFailureReason.network);
    }

    final status = response.statusCode;
    if (status == 200) {
      try {
        return AuthUser.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        );
      } on FormatException {
        throw const AuthFailure(AuthFailureReason.unexpected);
      } on TypeError {
        throw const AuthFailure(AuthFailureReason.unexpected);
      }
    }
    throw AuthFailure(switch (status) {
      400 => AuthFailureReason.invalidRequest,
      401 => AuthFailureReason.unauthorized,
      429 => AuthFailureReason.tooManyRequests,
      >= 500 => AuthFailureReason.unavailable,
      _ => AuthFailureReason.unexpected,
    });
  }
}
