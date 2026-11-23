import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/network/api.dart';
import '../auth/authenticated_client.dart';

final nfcCredentialGatewayProvider = Provider<NfcCredentialGateway>(
  (ref) => HttpNfcCredentialGateway(
    client: ref.watch(authenticatedClientProvider),
    baseUrl: ref.watch(apiBaseUrlProvider),
  ),
);

class NfcCredential {
  const NfcCredential({required this.token, required this.expiresAt});

  final String token;
  final DateTime expiresAt;
}

abstract interface class NfcCredentialGateway {
  Future<NfcCredential> issue();
}

class HttpNfcCredentialGateway implements NfcCredentialGateway {
  factory HttpNfcCredentialGateway({
    required http.Client client,
    required String baseUrl,
    Duration timeout = ApiConfig.timeout,
  }) => HttpNfcCredentialGateway._(
    client,
    baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
    timeout,
  );

  HttpNfcCredentialGateway._(this._client, this._baseUrl, this._timeout);

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  @override
  Future<NfcCredential> issue() async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/api/v1/access-credentials/nfc'),
            headers: const {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.timeout);
    } on Exception {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.network);
    }

    if (response.statusCode == 401) {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.unauthorized);
    }
    if (response.statusCode != 201) {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.unavailable);
    }
    try {
      final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final token = json['token'];
      final expiresAt = json['expiresAt'];
      if (token is! String || !RegExp(r'^[0-9a-f]{32}$').hasMatch(token) || expiresAt is! String) {
        throw const FormatException();
      }
      return NfcCredential(
        token: token,
        expiresAt: DateTime.parse(expiresAt).toUtc(),
      );
    } on FormatException {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.invalidResponse);
    } on TypeError {
      throw const NfcCredentialFailure(NfcCredentialFailureReason.invalidResponse);
    }
  }
}

enum NfcCredentialFailureReason { timeout, network, unauthorized, unavailable, invalidResponse }

class NfcCredentialFailure implements Exception {
  const NfcCredentialFailure(this.reason);

  final NfcCredentialFailureReason reason;
}
