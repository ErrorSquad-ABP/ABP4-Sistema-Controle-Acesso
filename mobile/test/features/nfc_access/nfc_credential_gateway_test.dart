import 'dart:convert';

import 'package:controle_acesso/features/nfc_access/nfc_credential_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  test('emite prova de 32 hex e converte a expiracao', () async {
    final client = MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, '/api/v1/access-credentials/nfc');
      return _json({
        'token': 'a' * 32,
        'expiresAt': '2026-11-23T19:00:00.000Z',
      }, 201);
    });
    final gateway = HttpNfcCredentialGateway(client: client, baseUrl: 'https://api');

    final credential = await gateway.issue();

    expect(credential.token, 'a' * 32);
    expect(credential.expiresAt, DateTime.utc(2026, 11, 23, 19));
  });

  test('recusa token fora do formato e resposta sem sessao', () async {
    final invalid = HttpNfcCredentialGateway(
      client: MockClient((_) async => _json({'token': 'xyz', 'expiresAt': '2026-11-23T19:00:00.000Z'}, 201)),
      baseUrl: 'https://api',
    );
    await expectLater(
      invalid.issue(),
      throwsA(isA<NfcCredentialFailure>().having(
        (failure) => failure.reason,
        'reason',
        NfcCredentialFailureReason.invalidResponse,
      )),
    );

    final unauthorized = HttpNfcCredentialGateway(
      client: MockClient((_) async => _json({'error': {}}, 401)),
      baseUrl: 'https://api',
    );
    await expectLater(
      unauthorized.issue(),
      throwsA(isA<NfcCredentialFailure>().having(
        (failure) => failure.reason,
        'reason',
        NfcCredentialFailureReason.unauthorized,
      )),
    );
  });
}
