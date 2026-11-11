import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:controle_acesso/features/authorizations/http_authorization_gateway.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';

Map<String, Object?> _item({
  String status = 'ACTIVE',
  String locationName = 'Edifício Aurora · Recepção',
}) => {
  'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  'user': {
    'id': '5b0b1f8e-0f4f-4d0e-8d1f-9a4f5a6c7d8e',
    'name': 'Maria Souza',
    'email': 'maria.souza@exemplo.com',
    'role': 'VISITOR',
  },
  'location': {
    'id': 'c1f2a3b4-1111-4222-8333-944455556666',
    'name': locationName,
  },
  'startsAt': '2026-10-27T17:00:00.000Z',
  'endsAt': '2026-10-27T21:00:00.000Z',
  'maxUses': 5,
  'usedCount': 2,
  'remainingUses': 3,
  'status': status,
  'canceledAt': null,
  'cancelReason': null,
  'createdAt': '2026-10-26T12:00:00.000Z',
};

Map<String, Object?> _page({String status = 'ACTIVE'}) => {
  'items': [_item(status: status)],
  'page': 1,
  'pageSize': 20,
  'total': 1,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpAuthorizationGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpAuthorizationGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(AuthorizationFailureReason reason) => throwsA(
  isA<AuthorizationFailure>().having((f) => f.reason, 'reason', reason),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('pede a primeira página do endpoint do contrato', () async {
    late http.Request sent;
    await _gateway((request) async {
      sent = request;
      return _json(_page());
    }).listMine();

    expect(sent.method, 'GET');
    expect(
      sent.url.toString(),
      'https://api.exemplo.com/api/v1/me/authorizations?page=1&pageSize=100',
    );
    expect(sent.headers['accept'], 'application/json');
  });

  test('200 vira a página do contrato', () async {
    final page = await _gateway((_) async => _json(_page(status: 'EXPIRED')))
        .listMine();

    expect(page.items.single.locationName, 'Edifício Aurora · Recepção');
    expect(page.items.single.status, AuthorizationStatus.expired);
  });

  test('lê o corpo como UTF-8 mesmo sem charset no cabeçalho', () async {
    final page = await _gateway(
      (_) async => http.Response.bytes(
        utf8.encode(jsonEncode(_page())),
        200,
        headers: {'content-type': 'application/json'},
      ),
    ).listMine();

    expect(page.items.single.locationName, 'Edifício Aurora · Recepção');
  });

  for (final (status, reason) in [
    (401, AuthorizationFailureReason.unauthorized),
    (429, AuthorizationFailureReason.unavailable),
    (500, AuthorizationFailureReason.unavailable),
    (503, AuthorizationFailureReason.unavailable),
    (400, AuthorizationFailureReason.unexpected),
    (404, AuthorizationFailureReason.unexpected),
    (204, AuthorizationFailureReason.unexpected),
  ]) {
    test('status $status vira ${reason.name}', () async {
      await expectLater(
        _gateway(
          (_) async => _json({
            'error': {'code': 'X', 'message': 'x'},
          }, status),
        ).listMine(),
        _failsWith(reason),
      );
    });
  }

  for (final (nome, body) in [
    ('corpo que não é JSON', 'isto não é json'),
    ('JSON que não é objeto', '[1, 2]'),
    (
      'situação fora do contrato',
      jsonEncode({
        'items': [
          {..._item(), 'status': 'TALVEZ'},
        ],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      }),
    ),
  ]) {
    test('200 com $nome vira resposta inesperada', () async {
      await expectLater(
        _gateway((_) async => http.Response(body, 200)).listMine(),
        _failsWith(AuthorizationFailureReason.unexpected),
      );
    });
  }

  test('sem resposta no prazo vira timeout', () async {
    await expectLater(
      _gateway(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      ).listMine(),
      _failsWith(AuthorizationFailureReason.timeout),
    );
  });

  test('falha de transporte vira rede', () async {
    await expectLater(
      _gateway((_) => throw http.ClientException('sem rede')).listMine(),
      _failsWith(AuthorizationFailureReason.network),
    );
    await expectLater(
      _gateway((_) => throw Exception('TLS recusado')).listMine(),
      _failsWith(AuthorizationFailureReason.network),
    );
  });

  test('base URL inválida vira resposta inesperada', () async {
    await expectLater(
      _gateway((_) async => _json(_page()), baseUrl: 'http://[::1').listMine(),
      _failsWith(AuthorizationFailureReason.unexpected),
    );
  });

  group('com o cliente autenticado', () {
    Future<(ProviderContainer, List<http.Request>)> setUp({
      required Future<http.Response> Function(http.Request) respond,
      InMemorySessionStore? store,
    }) async {
      final sent = <http.Request>[];
      final container = ProviderContainer.test(
        overrides: [
          apiBaseUrlProvider.overrideWithValue('https://api.exemplo.com'),
          ...authOverrides(store: store ?? InMemorySessionStore(sessionFor())),
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

    test('a consulta leva o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (_) async => _json(_page()),
      );

      await container.read(authorizationGatewayProvider).listMine();

      expect(sent.single.headers['Authorization'], 'Bearer jwt-maria');
    });

    test('401 encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(authorizationGatewayProvider).listMine(),
        _failsWith(AuthorizationFailureReason.unauthorized),
      );
      await pumpEventQueue();

      expect(container.read(currentSessionProvider), isNull);
    });

    test('sem sessão não envia nada e falha como não autorizado', () async {
      final (container, sent) = await setUp(
        store: InMemorySessionStore(),
        respond: (_) async => _json(_page()),
      );

      await expectLater(
        container.read(authorizationGatewayProvider).listMine(),
        _failsWith(AuthorizationFailureReason.unauthorized),
      );
      expect(sent, isEmpty);
    });
  });
}
