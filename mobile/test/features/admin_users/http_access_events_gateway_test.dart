import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/admin_users/access_events_contract.dart';
import 'package:controle_acesso/features/admin_users/http_access_events_gateway.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart'
    show AccessDecision, DenialReason;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

Map<String, Object?> _event({
  Object? method = 'QR',
  Object? decision = 'GRANTED',
  Object? reason,
  Object? user = const {
    'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
    'name': 'Maria Souza',
    'role': 'RESIDENT',
  },
  Object? location = const {
    'id': 'c1f2a3b4-1111-4222-8333-944455556666',
    'name': 'Edifício Aurora · Recepção',
  },
}) => {
  'id': 'e1f2a3b4-1111-4222-8333-944455556666',
  'occurredAt': '2026-11-10T12:00:00.000Z',
  'terminalId': 'aurora-recepcao',
  'method': method,
  'decision': decision,
  'reason': reason,
  'user': user,
  'location': location,
  'authorizationId': null,
  'distanceMeters': null,
};

Map<String, Object?> _page({List<Map<String, Object?>>? items}) => {
  'items': items ?? [_event()],
  'page': 1,
  'pageSize': 100,
  'total': (items ?? [_event()]).length,
};

http.Response _json(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

HttpAccessEventsGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpAccessEventsGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(AccessEventsFailureReason reason) => throwsA(
  isA<AccessEventsFailure>().having((f) => f.reason, 'reason', reason),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('GET /access-events', () {
    test('pede a primeira página sem filtro de decisão', () async {
      late http.Request sent;
      final page = await _gateway((request) async {
        sent = request;
        return _json(_page());
      }).list();

      expect(sent.method, 'GET');
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/access-events?page=1&pageSize=100',
      );
      expect(sent.headers['accept'], 'application/json');
      expect(page.items.single.method, AccessMethod.qr);
      expect(page.items.single.decision, AccessDecision.granted);
    });

    for (final (decision, code) in [
      (AccessDecision.granted, 'GRANTED'),
      (AccessDecision.denied, 'DENIED'),
    ]) {
      test('filtra por $code', () async {
        late http.Request sent;
        await _gateway((request) async {
          sent = request;
          return _json(_page());
        }).list(decision: decision);

        expect(sent.url.queryParameters['decision'], code);
      });
    }

    test('lê UF-8 e os campos do evento', () async {
      final page = await _gateway(
        (_) async => http.Response.bytes(
          utf8.encode(
            jsonEncode(
              _page(
                items: [
                  _event(
                    method: 'NFC',
                    decision: 'DENIED',
                    reason: 'OUT_OF_RANGE',
                  ),
                ],
              ),
            ),
          ),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).list();

      final event = page.items.single;
      expect(event.method, AccessMethod.nfc);
      expect(event.decision, AccessDecision.denied);
      expect(event.reason, DenialReason.outOfRange);
      expect(event.personName, 'Maria Souza');
      expect(event.locationName, 'Edifício Aurora · Recepção');
      expect(event.occurredAt.isUtc, isTrue);
    });

    for (final (status, reason) in [
      (400, AccessEventsFailureReason.invalidRequest),
      (401, AccessEventsFailureReason.unauthorized),
      (403, AccessEventsFailureReason.forbidden),
      (404, AccessEventsFailureReason.unexpected),
      (429, AccessEventsFailureReason.unavailable),
      (500, AccessEventsFailureReason.unavailable),
      (503, AccessEventsFailureReason.unavailable),
      (204, AccessEventsFailureReason.unexpected),
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
        'evento sem id',
        jsonEncode({
          ..._page(),
          'items': [
            {..._event()}..remove('id'),
          ],
        }),
      ),
      ('método desconhecido', jsonEncode(_page(items: [_event(method: 'BT')]))),
      (
        'decisão desconhecida',
        jsonEncode(_page(items: [_event(decision: 'MAYBE')])),
      ),
      (
        'data ilegível',
        jsonEncode({
          ..._page(),
          'items': [
            {..._event(), 'occurredAt': 'ontem'},
          ],
        }),
      ),
    ]) {
      test('200 com $nome vira resposta inesperada', () async {
        await expectLater(
          _gateway((_) async => http.Response(body, 200)).list(),
          _failsWith(AccessEventsFailureReason.unexpected),
        );
      });
    }

    test('sem resposta no prazo vira timeout', () async {
      await expectLater(
        _gateway(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ).list(),
        _failsWith(AccessEventsFailureReason.timeout),
      );
    });

    test('falha de transporte vira rede', () async {
      await expectLater(
        _gateway((_) => throw http.ClientException('sem rede')).list(),
        _failsWith(AccessEventsFailureReason.network),
      );
    });
  });

  group('com o cliente autenticado', () {
    Future<(ProviderContainer, List<http.Request>)> setUp({
      required Future<http.Response> Function(http.Request) respond,
    }) async {
      final sent = <http.Request>[];
      final container = ProviderContainer.test(
        overrides: [
          apiBaseUrlProvider.overrideWithValue('https://api.exemplo.com'),
          ...authOverrides(
            store: InMemorySessionStore(sessionFor(user: anaAdmin)),
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

    test('o histórico leva o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (_) async => _json(_page()),
      );

      await container.read(accessEventsGatewayProvider).list();

      expect(sent, hasLength(1));
      expect(sent.single.headers['Authorization'], 'Bearer jwt-maria');
    });

    test('401 encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(accessEventsGatewayProvider).list(),
        _failsWith(AccessEventsFailureReason.unauthorized),
      );
      await pumpEventQueue();

      expect(container.read(currentSessionProvider), isNull);
    });
  });
}
