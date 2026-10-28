import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import 'auth_contract.dart';

/// Relógio injetável: a validade da sessão é contada a partir dele.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

final authGatewayProvider = Provider<AuthGateway>(
  (ref) => HttpAuthGateway(
    client: ref.watch(httpClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
    now: ref.watch(clockProvider),
  ),
);

class HttpAuthGateway implements AuthGateway {
  HttpAuthGateway({
    required http.Client client,
    required String baseUrl,
    required DateTime Function() now,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), now, timeout);

  HttpAuthGateway._(this._client, this._baseUrl, this._now, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final DateTime Function() _now;
  final Duration _timeout;

  Uri _uri(String path) => Uri.parse('$_baseUrl/api/v1$path');

  @override
  Future<AuthSession> login(LoginRequest request) async {
    final body = await _send(
      () => _client.post(
        _uri('/auth/login'),
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request.toJson()),
      ),
    );
    return _parse(() => AuthSession.fromLoginResponse(body, now: _now()));
  }

  @override
  Future<AuthUser> currentUser(String accessToken) async {
    final body = await _send(
      () => _client.get(
        _uri('/auth/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      ),
    );
    return _parse(() => AuthUser.fromJson(body));
  }

  Future<Map<String, dynamic>> _send(
    Future<http.Response> Function() request,
  ) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const AuthFailure(AuthFailureReason.network);
    } on http.ClientException {
      throw const AuthFailure(AuthFailureReason.network);
    }

    final status = response.statusCode;
    if (status == 200) {
      return _parse(
        () =>
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    }
    throw AuthFailure(switch (status) {
      400 => AuthFailureReason.invalidRequest,
      401 => AuthFailureReason.unauthorized,
      429 => AuthFailureReason.tooManyRequests,
      >= 500 => AuthFailureReason.unavailable,
      _ => AuthFailureReason.unexpected,
    });
  }

  /// Corpo fora do contrato vira falha conhecida, nunca TypeError solto.
  T _parse<T>(T Function() parse) {
    try {
      return parse();
    } on FormatException {
      throw const AuthFailure(AuthFailureReason.unexpected);
    } on TypeError {
      throw const AuthFailure(AuthFailureReason.unexpected);
    }
  }
}
