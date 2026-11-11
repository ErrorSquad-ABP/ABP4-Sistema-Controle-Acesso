import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import 'location_contract.dart';

/// Uma página por vez; a tela pede a primeira com o maior tamanho aceito.
/// `GET /locations` não tem UI de paginação no design.
const int _pageSize = 100;

final locationGatewayProvider = Provider<LocationGateway>(
  (ref) => HttpLocationGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class HttpLocationGateway implements LocationGateway {
  HttpLocationGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpLocationGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<LocationPage> listActive({
    int page = 1,
    int pageSize = _pageSize,
  }) async {
    final response = await _send(
      () => _client
          .get(
            _uri('locations', {'page': '$page', 'pageSize': '$pageSize'}),
            headers: const {'Accept': 'application/json'},
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 200) {
      return _decode(
        response,
        (json) => LocationPage.fromJson(json),
      );
    }
    throw LocationFailure(_reasonFor(response.statusCode));
  }

  @override
  Future<Location> create(CreateLocationRequest request) async {
    final response = await _send(
      () => _client
          .post(
            _uri('locations'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout),
    );

    if (response.statusCode == 201) {
      return _decode(response, (json) => Location.fromJson(json));
    }
    throw LocationFailure(_reasonFor(response.statusCode));
  }

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl/api/v1/$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  Future<http.Response> _send(
    Future<http.Response> Function() request,
  ) async {
    try {
      return await request();
    } on TimeoutException {
      throw const LocationFailure(LocationFailureReason.timeout);
    } on AuthFailure catch (failure) {
      // Sem sessão o cliente autenticado recusa antes de enviar.
      throw LocationFailure(
        failure.reason == AuthFailureReason.unauthorized
            ? LocationFailureReason.unauthorized
            : LocationFailureReason.network,
      );
    } on http.ClientException {
      throw const LocationFailure(LocationFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const LocationFailure(LocationFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado).
      throw const LocationFailure(LocationFailureReason.network);
    }
  }

  T _decode<T>(
    http.Response response,
    T Function(Map<String, dynamic>) parse,
  ) {
    try {
      return parse(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
    } on FormatException {
      throw const LocationFailure(LocationFailureReason.unexpected);
    } on TypeError {
      throw const LocationFailure(LocationFailureReason.unexpected);
    }
  }

  static LocationFailureReason _reasonFor(int status) => switch (status) {
    400 => LocationFailureReason.invalidRequest,
    401 => LocationFailureReason.unauthorized,
    403 => LocationFailureReason.forbidden,
    429 || >= 500 => LocationFailureReason.unavailable,
    _ => LocationFailureReason.unexpected,
  };
}
