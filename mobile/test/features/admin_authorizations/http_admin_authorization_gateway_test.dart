import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorization_contract.dart';
import 'package:controle_acesso/features/admin_authorizations/http_admin_authorization_gateway.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';

const _userId = '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11';
const _locationId = 'c1f2a3b4-1111-4222-8333-944455556666';

Map<String, Object?> _item({
  String status = 'ACTIVE',
  String locationName = 'Edifício Aurora · Recepção',
}) => {
  'id': '0f1e2d3c-4b5a-4969-8778-665544332211',
  'user': {'id': _userId, 'name': 'Maria Souza', 'role': 'VISITOR'},
  'location': {'id': _locationId, 'name': locationName},
  'startsAt': '2026-11-20T17:00:00.000Z',
  'endsAt': '2026-11-20T21:00:00.000Z',
  'maxUses': 5,
  'usedCount': 2,
  'remainingUses': 3,
  'status': status,
  'canceledAt': null,
  'cancelReason': null,
  'createdAt': '2026-11-10T12:00:00.000Z',
};

Map<String, Object?> _page() => {
  'items': [_item()],
  'page': 1,
  'pageSize': 100,
  'total': 1,
};

Map<String, Object?> _user({String name = 'Maria Souza'}) => {
  'id': _userId,
  'name': name,
  'email': 'maria.souza@exemplo.com',
  'role': 'VISITOR',
  'active': true,
  'createdAt': '2026-11-10T12:00:00.000Z',
  'updatedAt': '2026-11-10T12:00:00.000Z',
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpAdminAuthorizationGateway _gateway(
  MockClientHandler handler, {
  Duration timeout = const Duration(seconds: 5),
}) => HttpAdminAuthorizationGateway(
  client: MockClient(handler),
  baseUrl: 'https://api.exemplo.com/',
  timeout: timeout,
);

Matcher _failsWith(AdminFailureReason reason) => throwsA(
  isA<AdminFailure>().having((failure) => failure.reason, 'reason', reason),
);

CreateAuthorizationRequest _request() => CreateAuthorizationRequest(
  userId: _userId,
  locationId: _locationId,
  startsAt: DateTime.utc(2026, 11, 20, 17),
  endsAt: DateTime.utc(2026, 11, 20, 21),
  maxUses: 5,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GET /authorizations', () {
    test(
      'pede a página sem filtro quando a situação não é escolhida',
      () async {
        late http.Request sent;
        final page = await _gateway((request) async {
          sent = request;
          return _json(_page());
        }).list();

        expect(
          sent.url.toString(),
          'https://api.exemplo.com/api/v1/authorizations?page=1&pageSize=100',
        );
        expect(sent.headers['accept'], 'application/json');
        expect(page.items.single.person.name, 'Maria Souza');
        expect(page.total, 1);
      },
    );

    test('manda o status do filtro escolhido', () async {
      late http.Request sent;
      await _gateway((request) async {
        sent = request;
        return _json(_page());
      }).list(status: AuthorizationStatus.expired);

      expect(sent.url.queryParameters['status'], 'EXPIRED');
    });

    for (final (status, reason) in [
      (400, AdminFailureReason.invalidRequest),
      (401, AdminFailureReason.unauthorized),
      (403, AdminFailureReason.forbidden),
      (429, AdminFailureReason.unavailable),
      (500, AdminFailureReason.unavailable),
      (404, AdminFailureReason.notFound),
      (204, AdminFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).list(),
          _failsWith(reason),
        );
      });
    }

    test('corpo fora do contrato vira resposta inesperada', () async {
      await expectLater(
        _gateway((_) async => http.Response('isto não é json', 200)).list(),
        _failsWith(AdminFailureReason.unexpected),
      );
      await expectLater(
        _gateway(
          (_) async => _json({
            'items': [_item(status: 'UNKNOWN')],
            'page': 1,
            'pageSize': 1,
            'total': 1,
          }),
        ).list(),
        _failsWith(AdminFailureReason.unexpected),
      );
    });

    test('sem resposta no prazo vira timeout', () async {
      await expectLater(
        _gateway(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ).list(),
        _failsWith(AdminFailureReason.timeout),
      );
    });

    test('falha de transporte vira rede', () async {
      await expectLater(
        _gateway((_) => throw http.ClientException('sem rede')).list(),
        _failsWith(AdminFailureReason.network),
      );
    });
  });

  group('POST /authorizations', () {
    test('envia o corpo do contrato e lê o 201', () async {
      late http.Request sent;
      final created = await _gateway((request) async {
        sent = request;
        return _json(_item(), 201);
      }).create(_request());

      expect(sent.method, 'POST');
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/authorizations',
      );
      expect(jsonDecode(sent.body), {
        'userId': _userId,
        'locationId': _locationId,
        'startsAt': '2026-11-20T17:00:00.000Z',
        'endsAt': '2026-11-20T21:00:00.000Z',
        'maxUses': 5,
      });
      expect(created.locationName, 'Edifício Aurora · Recepção');
    });

    for (final (status, reason) in [
      (400, AdminFailureReason.invalidRequest),
      (401, AdminFailureReason.unauthorized),
      (403, AdminFailureReason.forbidden),
      (422, AdminFailureReason.unprocessable),
      (429, AdminFailureReason.unavailable),
      (500, AdminFailureReason.unavailable),
      (200, AdminFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).create(_request()),
          _failsWith(reason),
        );
      });
    }
  });

  group('POST /authorizations/{id}/cancel', () {
    test('envia o motivo sem espaços nas pontas e lê o 200', () async {
      late http.Request sent;
      final canceled = await _gateway((request) async {
        sent = request;
        return _json(_item(status: 'CANCELED'));
      }).cancel('0f1e2d3c-4b5a-4969-8778-665544332211', '  Visita remarcada  ');

      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/authorizations/'
        '0f1e2d3c-4b5a-4969-8778-665544332211/cancel',
      );
      expect(jsonDecode(sent.body), {'reason': 'Visita remarcada'});
      expect(canceled.status, AuthorizationStatus.canceled);
    });

    for (final (status, reason) in [
      (400, AdminFailureReason.invalidRequest),
      (401, AdminFailureReason.unauthorized),
      (403, AdminFailureReason.forbidden),
      (404, AdminFailureReason.notFound),
      (409, AdminFailureReason.conflict),
      (429, AdminFailureReason.unavailable),
      (503, AdminFailureReason.unavailable),
      (201, AdminFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).cancel('0f1e2d3c-4b5a-4969-8778-665544332211', 'motivo'),
          _failsWith(reason),
        );
      });
    }
  });

  group('GET /users', () {
    test('pede a página com busca e só ativos', () async {
      late http.Request sent;
      final page = await HttpAdminUserGateway(
        client: MockClient((request) async {
          sent = request;
          return _json({
            'items': [_user()],
            'page': 1,
            'pageSize': 100,
            'total': 1,
          });
        }),
        baseUrl: 'https://api.exemplo.com',
      ).list(search: ' maria ', active: true);

      expect(sent.url.path, '/api/v1/users');
      expect(sent.url.queryParameters['search'], 'maria');
      expect(sent.url.queryParameters['active'], 'true');
      expect(page.items.single.email, 'maria.souza@exemplo.com');
    });

    test('omite a busca vazia', () async {
      late http.Request sent;
      await HttpAdminUserGateway(
        client: MockClient((request) async {
          sent = request;
          return _json({
            'items': <Object>[],
            'page': 1,
            'pageSize': 100,
            'total': 0,
          });
        }),
        baseUrl: 'https://api.exemplo.com',
      ).list(search: '   ');

      expect(sent.url.queryParameters.containsKey('search'), isFalse);
      expect(sent.url.queryParameters.containsKey('active'), isFalse);
    });

    test('usa a mesma tradução de falhas das autorizações', () async {
      await expectLater(
        HttpAdminUserGateway(
          client: MockClient(
            (_) async => _json({
              'error': {'code': 'FORBIDDEN', 'message': 'x'},
            }, 403),
          ),
          baseUrl: 'https://api.exemplo.com',
        ).list(),
        _failsWith(AdminFailureReason.forbidden),
      );
    });
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

    test('lista, criação e cancelamento levam o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (request) async {
          if (request.method == 'GET') return _json(_page());
          if (request.url.path.endsWith('/cancel')) {
            return _json(_item(status: 'CANCELED'));
          }
          return _json(_item(), 201);
        },
      );
      final gateway = container.read(adminAuthorizationGatewayProvider);

      await gateway.list();
      await gateway.create(_request());
      await gateway.cancel('0f1e2d3c-4b5a-4969-8778-665544332211', 'motivo');

      expect(sent, hasLength(3));
      for (final request in sent) {
        expect(request.headers['Authorization'], 'Bearer jwt-maria');
      }
    });

    test('401 encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(adminAuthorizationGatewayProvider).list(),
        _failsWith(AdminFailureReason.unauthorized),
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
        container.read(adminUserGatewayProvider).list(),
        _failsWith(AdminFailureReason.unauthorized),
      );
      expect(sent, isEmpty);
    });
  });
}
