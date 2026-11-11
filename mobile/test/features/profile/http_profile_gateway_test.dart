import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/profile/http_profile_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';

Map<String, Object?> _user({String name = 'Maria Souza Lima'}) => {
  'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  'name': name,
  'email': 'maria.souza@exemplo.com',
  'role': 'RESIDENT',
  'active': true,
  'createdAt': '2026-10-01T12:00:00.000Z',
  'updatedAt': '2026-10-27T12:00:00.000Z',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpProfileGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpProfileGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(AuthFailureReason reason) => throwsA(
  isA<AuthFailure>().having((failure) => failure.reason, 'reason', reason),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('envia só o nome no PATCH do contrato', () async {
    late http.Request sent;
    await _gateway((request) async {
      sent = request;
      return _json(_user());
    }).updateName('Maria Souza Lima');

    expect(sent.method, 'PATCH');
    expect(sent.url.toString(), 'https://api.exemplo.com/api/v1/me');
    expect(sent.headers['accept'], 'application/json');
    expect(sent.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(sent.body), {'name': 'Maria Souza Lima'});
  });

  test('200 devolve o usuário do shape de GET /auth/me', () async {
    final user = await _gateway((_) async => _json(_user())).updateName('x');

    expect(user.name, 'Maria Souza Lima');
    expect(user.email, 'maria.souza@exemplo.com');
    expect(user.role, UserRole.resident);
  });

  test('lê o corpo como UTF-8 mesmo sem charset no cabeçalho', () async {
    final user = await _gateway(
      (_) async => http.Response.bytes(utf8.encode(jsonEncode(_user())), 200),
    ).updateName('x');

    expect(user.name, 'Maria Souza Lima');
  });

  for (final (status, reason) in [
    (400, AuthFailureReason.invalidRequest),
    (401, AuthFailureReason.unauthorized),
    (429, AuthFailureReason.tooManyRequests),
    (500, AuthFailureReason.unavailable),
    (503, AuthFailureReason.unavailable),
    (404, AuthFailureReason.unexpected),
    (204, AuthFailureReason.unexpected),
  ]) {
    test('status $status vira ${reason.name}', () async {
      await expectLater(
        _gateway(
          (_) async => _json({
            'error': {'code': 'X', 'message': 'x'},
          }, status),
        ).updateName('x'),
        _failsWith(reason),
      );
    });
  }

  for (final (nome, body) in [
    ('corpo que não é JSON', 'isto não é json'),
    ('JSON que não é objeto', '[1, 2]'),
    ('usuário fora do contrato', jsonEncode({'id': '', 'name': ''})),
  ]) {
    test('200 com $nome vira resposta inesperada', () async {
      await expectLater(
        _gateway((_) async => http.Response(body, 200)).updateName('x'),
        _failsWith(AuthFailureReason.unexpected),
      );
    });
  }

  test('sem resposta no prazo vira timeout', () async {
    await expectLater(
      _gateway(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      ).updateName('x'),
      _failsWith(AuthFailureReason.timeout),
    );
  });

  test('falha de transporte vira rede', () async {
    await expectLater(
      _gateway((_) => throw http.ClientException('sem rede')).updateName('x'),
      _failsWith(AuthFailureReason.network),
    );
    await expectLater(
      _gateway((_) => throw Exception('TLS recusado')).updateName('x'),
      _failsWith(AuthFailureReason.network),
    );
  });

  test('base URL inválida vira resposta inesperada', () async {
    await expectLater(
      _gateway(
        (_) async => _json(_user()),
        baseUrl: 'http://[::1',
      ).updateName('x'),
      _failsWith(AuthFailureReason.unexpected),
    );
  });

  group('com o cliente autenticado', () {
    Future<(ProviderContainer, List<http.Request>)> setUp({
      required Future<http.Response> Function(http.Request) respond,
    }) async {
      final sent = <http.Request>[];
      final container = ProviderContainer.test(
        overrides: [
          apiBaseUrlProvider.overrideWithValue('https://api.exemplo.com'),
          ...authOverrides(store: InMemorySessionStore(sessionFor())),
          httpClientProvider.overrideWithValue(
            MockClient((request) {
              sent.add(request);
              return respond(request);
            }),
          ),
        ],
      );
      await container.read(sessionControllerProvider.future);
      return (container, sent);
    }

    test('a edição leva o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (_) async => _json(_user()),
      );

      await container.read(profileGatewayProvider).updateName('Maria Souza');

      expect(sent.single.headers['Authorization'], 'Bearer jwt-maria');
    });

    test('401 encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(profileGatewayProvider).updateName('Maria Souza'),
        _failsWith(AuthFailureReason.unauthorized),
      );
      await pumpEventQueue();

      expect(container.read(currentSessionProvider), isNull);
    });
  });
}
