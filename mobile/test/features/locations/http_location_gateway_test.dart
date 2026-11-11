import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/locations/http_location_gateway.dart';
import 'package:controle_acesso/features/locations/location_contract.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';

Map<String, Object?> _item({
  Object? description = 'Av. Central, 1200',
  Object? latitude = -23.1857,
  Object? longitude = -45.8846,
  Object? radiusMeters = 100,
  String name = 'Edifício Aurora · Recepção',
}) => {
  'id': 'c1f2a3b4-1111-4222-8333-944455556666',
  'name': name,
  'description': description,
  'latitude': latitude,
  'longitude': longitude,
  'radiusMeters': radiusMeters,
  'isActive': true,
  'createdAt': '2026-11-10T12:00:00.000Z',
  'updatedAt': '2026-11-10T12:00:00.000Z',
};

Map<String, Object?> _page({String name = 'Edifício Aurora · Recepção'}) => {
  'items': [_item(name: name)],
  'page': 1,
  'pageSize': 20,
  'total': 1,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpLocationGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpLocationGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(LocationFailureReason reason) => throwsA(
  isA<LocationFailure>().having((f) => f.reason, 'reason', reason),
);

CreateLocationRequest _request({String description = 'Av. Central, 1200'}) =>
    CreateLocationRequest(
      name: 'Edifício Aurora · Recepção',
      description: description,
      latitude: -23.1857,
      longitude: -45.8846,
      radiusMeters: 100,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GET /locations', () {
    test('pede a primeira página do endpoint do contrato', () async {
      late http.Request sent;
      await _gateway((request) async {
        sent = request;
        return _json(_page());
      }).listActive();

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/locations?page=1&pageSize=100',
      );
      expect(sent.headers['accept'], 'application/json');
    });

    test('200 vira a página do contrato', () async {
      final page = await _gateway(
        (_) async => _json(_page(name: 'Garagem')),
      ).listActive();

      expect(page.items.single.name, 'Garagem');
      expect(page.items.single.description, 'Av. Central, 1200');
      expect(page.items.single.radiusMeters, 100);
      expect(page.total, 1);
    });

    test('lê o corpo como UTF-8 mesmo sem charset no cabeçalho', () async {
      final page = await _gateway(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_page())),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).listActive();

      expect(page.items.single.name, 'Edifício Aurora · Recepção');
    });

    for (final (status, reason) in [
      (400, LocationFailureReason.invalidRequest),
      (401, LocationFailureReason.unauthorized),
      (403, LocationFailureReason.forbidden),
      (429, LocationFailureReason.unavailable),
      (500, LocationFailureReason.unavailable),
      (503, LocationFailureReason.unavailable),
      (404, LocationFailureReason.unexpected),
      (204, LocationFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).listActive(),
          _failsWith(reason),
        );
      });
    }

    for (final (nome, body) in [
      ('corpo que não é JSON', 'isto não é json'),
      ('JSON que não é objeto', '[1, 2]'),
      ('raio fora do contrato', jsonEncode({
        'items': [_item(radiusMeters: 101)],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      })),
      ('latitude fora do contrato', jsonEncode({
        'items': [_item(latitude: -91)],
        'page': 1,
        'pageSize': 20,
        'total': 1,
      })),
    ]) {
      test('200 com $nome vira resposta inesperada', () async {
        await expectLater(
          _gateway((_) async => http.Response(body, 200)).listActive(),
          _failsWith(LocationFailureReason.unexpected),
        );
      });
    }

    test('sem resposta no prazo vira timeout', () async {
      await expectLater(
        _gateway(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ).listActive(),
        _failsWith(LocationFailureReason.timeout),
      );
    });

    test('falha de transporte vira rede', () async {
      await expectLater(
        _gateway((_) => throw http.ClientException('sem rede')).listActive(),
        _failsWith(LocationFailureReason.network),
      );
      await expectLater(
        _gateway((_) => throw Exception('TLS recusado')).listActive(),
        _failsWith(LocationFailureReason.network),
      );
    });

    test('base URL inválida vira resposta inesperada', () async {
      await expectLater(
        _gateway(
          (_) async => _json(_page()),
          baseUrl: 'http://[::1',
        ).listActive(),
        _failsWith(LocationFailureReason.unexpected),
      );
    });
  });

  group('POST /locations', () {
    test('envia o corpo do contrato e lê o 201', () async {
      late http.Request sent;
      final created = await _gateway((request) async {
        sent = request;
        return _json(_item(), 201);
      }).create(_request());

      expect(sent.method, 'POST');
      expect(sent.url.toString(), 'https://api.exemplo.com/api/v1/locations');
      expect(sent.headers['accept'], 'application/json');
      expect(sent.headers['content-type'], 'application/json');
      expect(jsonDecode(sent.body), {
        'name': 'Edifício Aurora · Recepção',
        'description': 'Av. Central, 1200',
        'latitude': -23.1857,
        'longitude': -45.8846,
        'radiusMeters': 100,
      });
      expect(created.name, 'Edifício Aurora · Recepção');
      expect(created.radiusMeters, 100);
    });

    test('omite a descrição vazia do corpo', () async {
      late http.Request sent;
      await _gateway((request) async {
        sent = request;
        return _json(_item(description: null), 201);
      }).create(_request(description: '   '));

      expect(
        (jsonDecode(sent.body) as Map<String, dynamic>).containsKey(
          'description',
        ),
        isFalse,
      );
    });

    for (final (status, reason) in [
      (400, LocationFailureReason.invalidRequest),
      (401, LocationFailureReason.unauthorized),
      (403, LocationFailureReason.forbidden),
      (429, LocationFailureReason.unavailable),
      (500, LocationFailureReason.unavailable),
      (503, LocationFailureReason.unavailable),
      (200, LocationFailureReason.unexpected),
      (404, LocationFailureReason.unexpected),
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

    test('201 fora do contrato vira resposta inesperada', () async {
      await expectLater(
        _gateway(
          (_) async => _json(_item(radiusMeters: 0), 201),
        ).create(_request()),
        _failsWith(LocationFailureReason.unexpected),
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

    test('consulta e cadastro levam o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (request) async => request.method == 'GET'
            ? _json(_page())
            : _json(_item(), 201),
      );
      final gateway = container.read(locationGatewayProvider);

      await gateway.listActive();
      await gateway.create(_request());

      expect(sent, hasLength(2));
      expect(sent.first.headers['Authorization'], 'Bearer jwt-maria');
      expect(sent.last.headers['Authorization'], 'Bearer jwt-maria');
    });

    test('401 encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(locationGatewayProvider).listActive(),
        _failsWith(LocationFailureReason.unauthorized),
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
        container.read(locationGatewayProvider).listActive(),
        _failsWith(LocationFailureReason.unauthorized),
      );
      expect(sent, isEmpty);
    });
  });
}
