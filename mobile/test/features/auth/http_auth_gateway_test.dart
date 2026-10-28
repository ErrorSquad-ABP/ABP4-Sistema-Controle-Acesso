import 'dart:convert';

import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/http_auth_gateway.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

const _userJson = {
  'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  'name': 'Maria Souza',
  'email': 'maria.souza@exemplo.com',
  'role': 'RESIDENT',
  'active': true,
  'createdAt': '2026-10-01T10:00:00.000Z',
  'updatedAt': '2026-10-01T10:00:00.000Z',
};

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

http.Response _error(int status, String code) => _json({
  'error': {'code': code, 'message': code},
}, status);

HttpAuthGateway _gateway(MockClientHandler handler) => HttpAuthGateway(
  client: MockClient(handler),
  baseUrl: 'https://api.exemplo.com/',
  now: () => fixedNow,
);

Matcher _failsWith(AuthFailureReason reason) => throwsA(
  isA<AuthFailure>().having((failure) => failure.reason, 'reason', reason),
);

void main() {
  final request = LoginRequest(
    email: 'Maria.Souza@exemplo.com',
    password: 'senha-forte-123',
  );

  group('login', () {
    test('envia o LoginRequest e monta a sessão do LoginResponse', () async {
      late http.Request sent;
      final session = await _gateway((req) async {
        sent = req;
        return _json({
          'accessToken': 'jwt-maria',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
          'user': _userJson,
        }, 200);
      }).login(request);

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.exemplo.com/api/v1/auth/login');
      expect(sent.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(sent.body), {
        'email': 'maria.souza@exemplo.com',
        'password': 'senha-forte-123',
      });
      expect(session.accessToken, 'jwt-maria');
      expect(session.expiresAt, fixedNow.add(const Duration(hours: 1)));
      expect(session.user.name, 'Maria Souza');
      expect(session.user.role, UserRole.resident);
    });

    test('mapeia os códigos de erro do contrato', () async {
      const cases = {
        400: (AuthFailureReason.invalidRequest, 'INVALID_REQUEST'),
        401: (AuthFailureReason.unauthorized, 'UNAUTHORIZED'),
        429: (AuthFailureReason.tooManyRequests, 'TOO_MANY_REQUESTS'),
        503: (AuthFailureReason.unavailable, 'SERVICE_UNAVAILABLE'),
        500: (AuthFailureReason.unavailable, 'INTERNAL_ERROR'),
        404: (AuthFailureReason.unexpected, 'NOT_FOUND'),
      };
      for (final MapEntry(key: status, value: (reason, code))
          in cases.entries) {
        await expectLater(
          _gateway((_) async => _error(status, code)).login(request),
          _failsWith(reason),
          reason: 'HTTP $status',
        );
      }
    });

    test('falha de rede vira network', () async {
      await expectLater(
        _gateway((_) async => throw http.ClientException('offline'))
            .login(request),
        _failsWith(AuthFailureReason.network),
      );
    });

    test('tempo esgotado vira network', () async {
      final gateway = HttpAuthGateway(
        client: MockClient(
          (_) =>
              Future.delayed(const Duration(seconds: 1), () => _json({}, 200)),
        ),
        baseUrl: 'https://api.exemplo.com',
        now: () => fixedNow,
        timeout: const Duration(milliseconds: 10),
      );
      await expectLater(
        gateway.login(request),
        _failsWith(AuthFailureReason.network),
      );
    });

    test('resposta fora do contrato vira unexpected', () async {
      final bodies = [
        'não é json',
        jsonEncode({'accessToken': 'x', 'tokenType': 'Bearer'}),
        jsonEncode({
          'accessToken': 'x',
          'tokenType': 'Bearer',
          'expiresIn': 3600,
          'user': {..._userJson, 'role': 'ROOT'},
        }),
      ];
      for (final body in bodies) {
        await expectLater(
          _gateway((_) async => http.Response(body, 200)).login(request),
          _failsWith(AuthFailureReason.unexpected),
          reason: body,
        );
      }
    });
  });

  group('currentUser', () {
    test('envia o Bearer e devolve o usuário', () async {
      late http.Request sent;
      final user = await _gateway((req) async {
        sent = req;
        return _json(_userJson, 200);
      }).currentUser('jwt-maria');

      expect(sent.method, 'GET');
      expect(sent.url.path, '/api/v1/auth/me');
      expect(sent.headers['Authorization'], 'Bearer jwt-maria');
      expect(user.email, 'maria.souza@exemplo.com');
    });

    test('token recusado vira unauthorized', () async {
      await expectLater(
        _gateway((_) async => _error(401, 'UNAUTHORIZED'))
            .currentUser('vencido'),
        _failsWith(AuthFailureReason.unauthorized),
      );
    });
  });
}
