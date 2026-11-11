import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/admin_users/http_admin_users_gateway.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

Map<String, Object?> _user({
  String name = 'Maria Souza',
  String email = 'maria.souza@exemplo.com',
  Object? role = 'RESIDENT',
  Object? active = true,
}) => {
  'id': 'c1f2a3b4-1111-4222-8333-944455556666',
  'name': name,
  'email': email,
  'role': role,
  'active': active,
  'createdAt': '2026-11-10T12:00:00.000Z',
  'updatedAt': '2026-11-10T12:00:00.000Z',
};

Map<String, Object?> _page({String name = 'Maria Souza'}) => {
  'items': [_user(name: name)],
  'page': 1,
  'pageSize': 100,
  'total': 1,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpAdminUsersGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpAdminUsersGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(AdminUsersFailureReason reason) =>
    throwsA(isA<AdminUsersFailure>().having((f) => f.reason, 'reason', reason));

UpdateAdminUserRequest _update({
  String name = 'Maria Souza',
  UserRole role = UserRole.resident,
  bool active = true,
}) => UpdateAdminUserRequest(name: name, role: role, active: active);

CreateAdminUserRequest _create() => CreateAdminUserRequest(
  name: 'Renata Alves',
  email: ' Renata.Alves@Exemplo.com ',
  password: 'senha-forte-123',
  role: UserRole.visitor,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GET /users', () {
    test('pede a primeira página com o termo de busca', () async {
      late http.Request sent;
      final page = await _gateway((request) async {
        sent = request;
        return _json(_page(name: 'Renata Alves'));
      }).list(search: '  renata  ');

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/users?page=1&pageSize=100&search=renata',
      );
      expect(sent.headers['accept'], 'application/json');
      expect(page.items.single.name, 'Renata Alves');
      expect(page.total, 1);
    });

    test('sem busca não manda o parâmetro', () async {
      late http.Request sent;
      await _gateway((request) async {
        sent = request;
        return _json(_page());
      }).list(search: '   ');

      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/users?page=1&pageSize=100',
      );
    });

    test('lê o corpo como UTF-8 mesmo sem charset no cabeçalho', () async {
      final page = await _gateway(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_page())),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).list();

      expect(page.items.single.email, 'maria.souza@exemplo.com');
    });

    for (final (status, reason) in [
      (400, AdminUsersFailureReason.invalidRequest),
      (401, AdminUsersFailureReason.unauthorized),
      (403, AdminUsersFailureReason.forbidden),
      (404, AdminUsersFailureReason.notFound),
      (409, AdminUsersFailureReason.conflict),
      (429, AdminUsersFailureReason.unavailable),
      (500, AdminUsersFailureReason.unavailable),
      (503, AdminUsersFailureReason.unavailable),
      (204, AdminUsersFailureReason.unexpected),
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

    for (final (nome, body) in [
      ('corpo que não é JSON', 'isto não é json'),
      ('JSON que não é objeto', '[1, 2]'),
      (
        'item sem id',
        jsonEncode({
          ..._page(),
          'items': [
            {'name': 'X'},
          ],
        }),
      ),
      (
        'papel desconhecido',
        jsonEncode({
          'items': [_user(role: 'OWNER')],
          'page': 1,
          'pageSize': 100,
          'total': 1,
        }),
      ),
      (
        'situação que não é booleana',
        jsonEncode({
          'items': [_user(active: 'true')],
          'page': 1,
          'pageSize': 100,
          'total': 1,
        }),
      ),
    ]) {
      test('200 com $nome vira resposta inesperada', () async {
        await expectLater(
          _gateway((_) async => http.Response(body, 200)).list(),
          _failsWith(AdminUsersFailureReason.unexpected),
        );
      });
    }

    test('sem resposta no prazo vira timeout', () async {
      await expectLater(
        _gateway(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ).list(),
        _failsWith(AdminUsersFailureReason.timeout),
      );
    });

    test('falha de transporte vira rede', () async {
      await expectLater(
        _gateway((_) => throw http.ClientException('sem rede')).list(),
        _failsWith(AdminUsersFailureReason.network),
      );
      await expectLater(
        _gateway((_) => throw Exception('TLS recusado')).list(),
        _failsWith(AdminUsersFailureReason.network),
      );
    });

    test('base URL inválida vira resposta inesperada', () async {
      await expectLater(
        _gateway((_) async => _json(_page()), baseUrl: 'http://[::1').list(),
        _failsWith(AdminUsersFailureReason.unexpected),
      );
    });
  });

  group('POST /users', () {
    test('envia o corpo do contrato e lê o 201', () async {
      late http.Request sent;
      final created = await _gateway((request) async {
        sent = request;
        return _json(_user(name: 'Renata Alves'), 201);
      }).create(_create());

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.exemplo.com/api/v1/users');
      expect(sent.headers['content-type'], 'application/json');
      expect(jsonDecode(sent.body), {
        'name': 'Renata Alves',
        'email': 'renata.alves@exemplo.com',
        'password': 'senha-forte-123',
        'role': 'VISITOR',
      });
      expect(created.name, 'Renata Alves');
    });

    for (final (status, reason) in [
      (400, AdminUsersFailureReason.invalidRequest),
      (401, AdminUsersFailureReason.unauthorized),
      (403, AdminUsersFailureReason.forbidden),
      (409, AdminUsersFailureReason.conflict),
      (429, AdminUsersFailureReason.unavailable),
      (500, AdminUsersFailureReason.unavailable),
      (200, AdminUsersFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).create(_create()),
          _failsWith(reason),
        );
      });
    }

    test('201 fora do contrato vira resposta inesperada', () async {
      await expectLater(
        _gateway((_) async => _json(_user(name: ''), 201)).create(_create()),
        _failsWith(AdminUsersFailureReason.unexpected),
      );
    });
  });

  group('GET /users/:id', () {
    test('consulta a conta pelo id', () async {
      late http.Request sent;
      final user = await _gateway((request) async {
        sent = request;
        return _json(_user());
      }).findById('c1f2a3b4-1111-4222-8333-944455556666');

      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/users/c1f2a3b4-1111-4222-8333-944455556666',
      );
      expect(user.role, UserRole.resident);
      expect(user.active, isTrue);
    });

    for (final (status, reason) in [
      (400, AdminUsersFailureReason.invalidRequest),
      (401, AdminUsersFailureReason.unauthorized),
      (403, AdminUsersFailureReason.forbidden),
      (404, AdminUsersFailureReason.notFound),
      (500, AdminUsersFailureReason.unavailable),
      (200, AdminUsersFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => status == 200
                ? http.Response('não é json', 200)
                : _json({
                    'error': {'code': 'X', 'message': 'x'},
                  }, status),
          ).findById('id'),
          _failsWith(reason),
        );
      });
    }
  });

  group('PATCH /users/:id', () {
    test('envia nome, perfil e situação', () async {
      late http.Request sent;
      final updated =
          await _gateway((request) async {
            sent = request;
            return _json(_user(name: 'Maria Souza Lima', role: 'ADMIN'));
          }).update(
            'id-com-hifen',
            _update(
              name: ' Maria Souza Lima ',
              role: UserRole.admin,
              active: false,
            ),
          );

      expect(sent.method, 'PATCH');
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/users/id-com-hifen',
      );
      expect(jsonDecode(sent.body), {
        'name': 'Maria Souza Lima',
        'role': 'ADMIN',
        'active': false,
      });
      expect(updated.role, UserRole.admin);
    });

    for (final (status, reason) in [
      (400, AdminUsersFailureReason.invalidRequest),
      (401, AdminUsersFailureReason.unauthorized),
      (403, AdminUsersFailureReason.forbidden),
      (404, AdminUsersFailureReason.notFound),
      (409, AdminUsersFailureReason.conflict),
      (429, AdminUsersFailureReason.unavailable),
      (200, AdminUsersFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => status == 200
                ? http.Response('não é json', 200)
                : _json({
                    'error': {'code': 'X', 'message': 'x'},
                  }, status),
          ).update('id', _update()),
          _failsWith(reason),
        );
      });
    }
  });

  group('DELETE /users/:id', () {
    test('aceita o 204 sem corpo', () async {
      late http.Request sent;
      await _gateway((request) async {
        sent = request;
        return http.Response('', 204);
      }).delete('id');

      expect(sent.method, 'DELETE');
      expect(sent.url.toString(), 'https://api.exemplo.com/api/v1/users/id');
    });

    for (final (status, reason) in [
      (401, AdminUsersFailureReason.unauthorized),
      (403, AdminUsersFailureReason.forbidden),
      (404, AdminUsersFailureReason.notFound),
      (409, AdminUsersFailureReason.conflict),
      (429, AdminUsersFailureReason.unavailable),
      (503, AdminUsersFailureReason.unavailable),
      (200, AdminUsersFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).delete('id'),
          _failsWith(reason),
        );
      });
    }
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
          ...authOverrides(
            store: store ?? InMemorySessionStore(sessionFor(user: anaAdmin)),
          ),
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

    test('lista, cria, edita e exclui com o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (request) async => switch (request.method) {
          'GET' => _json(
            request.url.path.endsWith('/users') ? _page() : _user(),
          ),
          'POST' => _json(_user(), 201),
          'PATCH' => _json(_user()),
          _ => http.Response('', 204),
        },
      );
      final gateway = container.read(adminUsersGatewayProvider);

      await gateway.list();
      await gateway.findById('id');
      await gateway.create(_create());
      await gateway.update('id', _update());
      await gateway.delete('id');

      expect(sent, hasLength(5));
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
        container.read(adminUsersGatewayProvider).list(),
        _failsWith(AdminUsersFailureReason.unauthorized),
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
        container.read(adminUsersGatewayProvider).list(),
        _failsWith(AdminUsersFailureReason.unauthorized),
      );
      expect(sent, isEmpty);
    });
  });
}
