import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import '../authorizations/authorization_contract.dart';
import 'admin_authorization_contract.dart';

/// Uma página por vez, no maior tamanho aceito: a administração não tem UI de
/// paginação. Pessoas e locais usam o mesmo teto do contrato (100).
const int _pageSize = 100;

final adminAuthorizationGatewayProvider = Provider<AdminAuthorizationGateway>(
  (ref) => HttpAdminAuthorizationGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

final adminUserGatewayProvider = Provider<AdminUserGateway>(
  (ref) => HttpAdminUserGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

/// Transporte comum das rotas de administração: Bearer pelo cliente
/// autenticado, mesma tradução de falhas de transporte e de corpo inválido.
abstract class _AdminApi {
  _AdminApi(http.Client client, String baseUrl, Duration timeout)
    : _client = client,
      _baseUrl = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl,
      _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl/api/v1/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const AdminFailure(AdminFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw AdminFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? AdminFailureReason.unauthorized
            : AdminFailureReason.network,
      );
    } on http.ClientException {
      throw const AdminFailure(AdminFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AdminFailure(AdminFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const AdminFailure(AdminFailureReason.network);
    }
  }

  /// Corpo fora do contrato vira falha conhecida, nunca TypeError solto.
  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on FormatException {
      throw const AdminFailure(AdminFailureReason.unexpected);
    } on TypeError {
      throw const AdminFailure(AdminFailureReason.unexpected);
    }
  }

  AdminFailure _failureFor(int status) => AdminFailure(switch (status) {
    400 => AdminFailureReason.invalidRequest,
    401 => AdminFailureReason.unauthorized,
    403 => AdminFailureReason.forbidden,
    404 => AdminFailureReason.notFound,
    409 => AdminFailureReason.conflict,
    422 => AdminFailureReason.unprocessable,
    429 || >= 500 => AdminFailureReason.unavailable,
    _ => AdminFailureReason.unexpected,
  });
}

class HttpAdminAuthorizationGateway extends _AdminApi
    implements AdminAuthorizationGateway {
  HttpAdminAuthorizationGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : super(client, baseUrl, timeout);

  @override
  Future<AuthorizationPage> list({
    int page = 1,
    int pageSize = _pageSize,
    AuthorizationStatus? status,
  }) async {
    final response = await _send(
      () => _client
          .get(
            _uri('authorizations', {
              'page': '$page',
              'pageSize': '$pageSize',
              if (status != null) 'status': status.code,
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 200) {
      throw _failureFor(response.statusCode);
    }
    return _decode(response, AuthorizationPage.fromJson);
  }

  @override
  Future<Authorization> create(CreateAuthorizationRequest request) async {
    final response = await _send(
      () => _client
          .post(
            _uri('authorizations'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 201) {
      throw _failureFor(response.statusCode);
    }
    return _decode(response, Authorization.fromJson);
  }

  @override
  Future<Authorization> cancel(String id, String reason) async {
    final response = await _send(
      () => _client
          .post(
            _uri('authorizations/${Uri.encodeComponent(id)}/cancel'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'reason': reason.trim()}),
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 200) {
      throw _failureFor(response.statusCode);
    }
    return _decode(response, Authorization.fromJson);
  }
}

class HttpAdminUserGateway extends _AdminApi implements AdminUserGateway {
  HttpAdminUserGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : super(client, baseUrl, timeout);

  @override
  Future<AdminUserPage> list({
    String? search,
    int page = 1,
    int pageSize = _pageSize,
    bool? active,
  }) async {
    final query = (search ?? '').trim();
    final response = await _send(
      () => _client
          .get(
            _uri('users', {
              'page': '$page',
              'pageSize': '$pageSize',
              // `search` do contrato exige de 1 a 120 caracteres.
              if (query.isNotEmpty) 'search': query,
              if (active != null) 'active': '$active',
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode != 200) {
      throw _failureFor(response.statusCode);
    }
    return _decode(response, AdminUserPage.fromJson);
  }
}
