import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import '../scanner/access_contract.dart' show AccessDecision;
import 'access_events_contract.dart';

/// Maior página aceita pela API. Sem paginação no design, o filtro de decisão
/// é o recorte que o administrador tem; a tela avisa quando há mais eventos.
const int _pageSize = 100;

final accessEventsGatewayProvider = Provider<AccessEventsGateway>(
  (ref) => HttpAccessEventsGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class HttpAccessEventsGateway implements AccessEventsGateway {
  HttpAccessEventsGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpAccessEventsGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<AdminAccessEventPage> list({
    AccessDecision? decision,
    int page = 1,
    int pageSize = _pageSize,
  }) async {
    final response = await _send(
      () => _client
          .get(
            _uri('access-events', {
              'page': '$page',
              'pageSize': '$pageSize',
              if (decision != null) 'decision': _decisionCode(decision),
            }),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 200) {
      return _decode(response, AdminAccessEventPage.fromJson);
    }
    throw AccessEventsFailure(_reasonFor(response.statusCode));
  }

  static String _decisionCode(AccessDecision decision) =>
      decision == AccessDecision.granted ? 'GRANTED' : 'DENIED';

  Uri _uri(String path, Map<String, String> query) =>
      Uri.parse('$_baseUrl/api/v1/$path').replace(queryParameters: query);

  Future<http.Response> _send(Future<http.Response> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const AccessEventsFailure(AccessEventsFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw AccessEventsFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? AccessEventsFailureReason.unauthorized
            : AccessEventsFailureReason.network,
      );
    } on http.ClientException {
      throw const AccessEventsFailure(AccessEventsFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AccessEventsFailure(AccessEventsFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const AccessEventsFailure(AccessEventsFailureReason.network);
    }
  }

  T _decode<T>(http.Response response, T Function(Map<String, dynamic>) parse) {
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on FormatException {
      throw const AccessEventsFailure(AccessEventsFailureReason.unexpected);
    } on TypeError {
      throw const AccessEventsFailure(AccessEventsFailureReason.unexpected);
    }
  }

  static AccessEventsFailureReason _reasonFor(int status) => switch (status) {
    400 => AccessEventsFailureReason.invalidRequest,
    401 => AccessEventsFailureReason.unauthorized,
    403 => AccessEventsFailureReason.forbidden,
    429 || >= 500 => AccessEventsFailureReason.unavailable,
    _ => AccessEventsFailureReason.unexpected,
  };
}
