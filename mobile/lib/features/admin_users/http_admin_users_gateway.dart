import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import 'admin_users_contract.dart';

/// Uma página por vez; a tela pede a primeira com o maior tamanho aceito.
/// Não há paginação no design: a busca é a forma de achar quem está além dela.
const int _pageSize = 100;

final adminUsersGatewayProvider = Provider<AdminUsersGateway>(
  (ref) => HttpAdminUsersGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class HttpAdminUsersGateway implements AdminUsersGateway {
  HttpAdminUsersGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpAdminUsersGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<AdminUserPage> list({
    String search = '',
    int page = 1,
    int pageSize = _pageSize,
  }) async {
    final term = search.trim();
    final response = await _send(
      () => _client
          .get(
            _uri('users', {
              'page': '$page',
              'pageSize': '$pageSize',
              if (term.isNotEmpty) 'search': term,
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 200) {
      return _decode(response, AdminUserPage.fromJson);
    }
    throw AdminUsersFailure(_reasonFor(response.statusCode));
  }

  @override
  Future<AdminUser> findById(String id) async {
    final response = await _send(
      () => _client
          .get(
            _uri('users/${Uri.encodeComponent(id)}'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 200) {
      return _decode(response, AdminUser.fromJson);
    }
    throw AdminUsersFailure(_reasonFor(response.statusCode));
  }

  @override
  Future<AdminUser> create(CreateAdminUserRequest request) async {
    final response = await _send(
      () => _client
          .post(
            _uri('users'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 201) {
      return _decode(response, AdminUser.fromJson);
    }
    throw AdminUsersFailure(_reasonFor(response.statusCode));
  }

  @override
  Future<AdminUser> update(String id, UpdateAdminUserRequest request) async {
    final response = await _send(
      () => _client
          .patch(
            _uri('users/${Uri.encodeComponent(id)}'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 200) {
      return _decode(response, AdminUser.fromJson);
    }
    throw AdminUsersFailure(_reasonFor(response.statusCode));
  }

  @override
  Future<void> delete(String id) async {
    final response = await _send(
      () => _client
          .delete(
            _uri('users/${Uri.encodeComponent(id)}'),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 204) return;
    throw AdminUsersFailure(_reasonFor(response.statusCode));
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl/api/v1/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const AdminUsersFailure(AdminUsersFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw AdminUsersFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? AdminUsersFailureReason.unauthorized
            : AdminUsersFailureReason.network,
      );
    } on http.ClientException {
      throw const AdminUsersFailure(AdminUsersFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AdminUsersFailure(AdminUsersFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const AdminUsersFailure(AdminUsersFailureReason.network);
    }
  }

  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on FormatException {
      throw const AdminUsersFailure(AdminUsersFailureReason.unexpected);
    } on TypeError {
      throw const AdminUsersFailure(AdminUsersFailureReason.unexpected);
    }
  }

  static AdminUsersFailureReason _reasonFor(int status) => switch (status) {
    400 => AdminUsersFailureReason.invalidRequest,
    401 => AdminUsersFailureReason.unauthorized,
    403 => AdminUsersFailureReason.forbidden,
    404 => AdminUsersFailureReason.notFound,
    409 => AdminUsersFailureReason.conflict,
    429 || >= 500 => AdminUsersFailureReason.unavailable,
    _ => AdminUsersFailureReason.unexpected,
  };
}
