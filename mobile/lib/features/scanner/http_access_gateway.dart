import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/auth_contract.dart';
import '../auth/authenticated_client.dart';
import 'access_contract.dart';

final accessGatewayProvider = Provider<AccessGateway>(
  (ref) => HttpAccessGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class HttpAccessGateway implements AccessGateway {
  HttpAccessGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) : this._(client, _trimSlash(baseUrl), timeout);

  HttpAccessGateway._(this._client, this._baseUrl, this._timeout);

  static String _trimSlash(String url) =>
      url.endsWith('/') ? url.substring(0, url.length - 1) : url;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<AccessResult> requestQrAccess(QrAccessRequest request) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/access-events/qr'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(request.toJson()),
          )
          .timeout(_timeout);
    } on AuthFailure {
      // Sem sessão: o cliente autenticado nem chega a enviar.
      throw const AccessFailure(AccessFailureReason.unauthorized);
    } on TimeoutException {
      throw const AccessFailure(AccessFailureReason.timeout);
    } on http.ClientException {
      throw const AccessFailure(AccessFailureReason.network);
    } on FormatException {
      // API_BASE_URL que não forma uma URL válida.
      throw const AccessFailure(AccessFailureReason.unexpected);
    } on Exception {
      // Transporte que o http não converte em ClientException (TLS recusado de
      // um Wi-Fi com portal cativo, por exemplo).
      throw const AccessFailure(AccessFailureReason.network);
    }

    final status = response.statusCode;
    // Negar acesso não é erro HTTP: volta 200 com decision DENIED.
    if (status == 200) {
      try {
        return AccessResult.fromJson(
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
        );
      } on FormatException {
        throw const AccessFailure(AccessFailureReason.unexpected);
      } on TypeError {
        throw const AccessFailure(AccessFailureReason.unexpected);
      }
    }
    throw AccessFailure(switch (status) {
      400 => AccessFailureReason.invalidRequest,
      401 => AccessFailureReason.unauthorized,
      429 => AccessFailureReason.tooManyRequests,
      >= 500 => AccessFailureReason.unavailable,
      _ => AccessFailureReason.unexpected,
    });
  }
}
