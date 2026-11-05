import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../auth/fakes.dart';

http.Response _json(Object body, int status) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, Object?> _accessResult({
  String decision = 'GRANTED',
  String? reason,
}) => {
  'decision': decision,
  'reason': reason,
  'message': 'Acesso autorizado',
  'event': {
    'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
    'occurredAt': '2026-10-27T17:32:10.000Z',
    'terminalId': 'terminal-01',
    'method': 'QR',
    'decision': decision,
    'reason': reason,
    'location': {
      'id': '5b0b1f8e-0f4f-4d0e-8d1f-9a4f5a6c7d8e',
      'name': 'Edifício Aurora · Recepção',
    },
  },
};

const _request = QrAccessRequest(
  qrToken: 'v1.terminal-01.1790000000.1790000010.sig',
  terminalId: 'terminal-01',
  position: GeoCoordinate(
    latitude: -23.1857,
    longitude: -45.8846,
    accuracyMeters: 8,
  ),
  requestId: '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
);

HttpAccessGateway _gateway(
  MockClientHandler handler, {
  String baseUrl = 'https://api.exemplo.com/',
  Duration timeout = const Duration(seconds: 5),
}) => HttpAccessGateway(
  client: MockClient(handler),
  baseUrl: baseUrl,
  timeout: timeout,
);

Matcher _failsWith(AccessFailureReason reason) => throwsA(
  isA<AccessFailure>().having((failure) => failure.reason, 'reason', reason),
);

void main() {
  // O controller de sessão registra um AppLifecycleListener.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('requestQrAccess', () {
    test('envia o pedido ao endpoint do contrato', () async {
      late http.Request sent;
      await _gateway((req) async {
        sent = req;
        return _json(_accessResult(), 200);
      }).requestQrAccess(_request);

      expect(sent.method, 'POST');
      // A barra final do API_BASE_URL não duplica no caminho.
      expect(
        sent.url.toString(),
        'https://api.exemplo.com/api/v1/access-events/qr',
      );
      expect(sent.headers['content-type'], contains('application/json'));
      expect(sent.headers['accept'], 'application/json');
      expect(jsonDecode(sent.body), {
        'qrToken': 'v1.terminal-01.1790000000.1790000010.sig',
        'terminalId': 'terminal-01',
        'position': {
          'latitude': -23.1857,
          'longitude': -45.8846,
          'accuracyMeters': 8,
        },
        'requestId': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
      });
    });

    test('200 liberado vira o resultado com o local do evento', () async {
      final result = await _gateway((_) async => _json(_accessResult(), 200))
          .requestQrAccess(_request);

      expect(result.decision, AccessDecision.granted);
      expect(result.locationName, 'Edifício Aurora · Recepção');
    });

    test('200 negado não é erro: devolve a decisão com o motivo', () async {
      final result = await _gateway(
        (_) async => _json(
          _accessResult(decision: 'DENIED', reason: 'OUT_OF_RANGE'),
          200,
        ),
      ).requestQrAccess(_request);

      expect(result.decision, AccessDecision.denied);
      expect(result.reason, DenialReason.outOfRange);
    });

    test('lê o corpo como UTF-8 mesmo sem charset no cabeçalho', () async {
      final result = await _gateway(
        (_) async => http.Response.bytes(
          utf8.encode(jsonEncode(_accessResult())),
          200,
          headers: {'content-type': 'application/json'},
        ),
      ).requestQrAccess(_request);

      expect(result.locationName, 'Edifício Aurora · Recepção');
    });

    for (final (status, reason) in [
      (400, AccessFailureReason.invalidRequest),
      (401, AccessFailureReason.unauthorized),
      (429, AccessFailureReason.tooManyRequests),
      (500, AccessFailureReason.unavailable),
      (503, AccessFailureReason.unavailable),
      (404, AccessFailureReason.unexpected),
      (302, AccessFailureReason.unexpected),
      (204, AccessFailureReason.unexpected),
    ]) {
      test('status $status vira ${reason.name}', () async {
        await expectLater(
          _gateway(
            (_) async => _json({
              'error': {'code': 'X', 'message': 'x'},
            }, status),
          ).requestQrAccess(_request),
          _failsWith(reason),
        );
      });
    }

    for (final (nome, body) in [
      ('corpo que não é JSON', 'isto não é json'),
      ('JSON que não é objeto', '[1, 2]'),
      ('decisão fora do contrato', '{"decision":"TALVEZ"}'),
      ('evento ausente', '{"decision":"GRANTED"}'),
    ]) {
      test('200 com $nome vira resposta inesperada', () async {
        await expectLater(
          _gateway((_) async => http.Response(body, 200))
              .requestQrAccess(_request),
          _failsWith(AccessFailureReason.unexpected),
        );
      });
    }

    test('sem resposta no prazo vira timeout', () async {
      await expectLater(
        _gateway(
          (_) => Completer<http.Response>().future,
          timeout: const Duration(milliseconds: 20),
        ).requestQrAccess(_request),
        _failsWith(AccessFailureReason.timeout),
      );
    });

    test('falha de transporte vira rede', () async {
      await expectLater(
        _gateway((_) => throw http.ClientException('sem rede'))
            .requestQrAccess(_request),
        _failsWith(AccessFailureReason.network),
      );
      await expectLater(
        _gateway((_) => throw Exception('TLS recusado'))
            .requestQrAccess(_request),
        _failsWith(AccessFailureReason.network),
      );
    });

    test('API_BASE_URL inválida vira resposta inesperada', () async {
      await expectLater(
        _gateway(
          (_) async => _json(_accessResult(), 200),
          baseUrl: 'http://[::1',
        ).requestQrAccess(_request),
        _failsWith(AccessFailureReason.unexpected),
      );
    });

    test(
      'sem sessão o cliente autenticado recusa e vira não autorizado',
      () async {
        await expectLater(
          _gateway(
            (_) => throw const AuthFailure(AuthFailureReason.unauthorized),
          ).requestQrAccess(_request),
          _failsWith(AccessFailureReason.unauthorized),
        );
      },
    );
  });

  group('com o cliente autenticado (US-27)', () {
    const baseUrl = 'https://api.exemplo.com';

    Future<(ProviderContainer, List<http.Request>)> setUp({
      required Future<http.Response> Function(http.Request) respond,
      InMemorySessionStore? store,
    }) async {
      final sent = <http.Request>[];
      final container = ProviderContainer.test(
        overrides: [
          apiBaseUrlProvider.overrideWithValue(baseUrl),
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

    test('o pedido leva o Bearer da sessão', () async {
      final (container, sent) = await setUp(
        respond: (_) async => _json(_accessResult(), 200),
      );

      await container.read(accessGatewayProvider).requestQrAccess(_request);

      expect(sent.single.headers['Authorization'], 'Bearer jwt-maria');
    });

    test('401 recusa o pedido e encerra a sessão', () async {
      final (container, _) = await setUp(
        respond: (_) async => _json({
          'error': {'code': 'UNAUTHORIZED', 'message': 'x'},
        }, 401),
      );

      await expectLater(
        container.read(accessGatewayProvider).requestQrAccess(_request),
        _failsWith(AccessFailureReason.unauthorized),
      );
      await pumpEventQueue();

      expect(container.read(currentSessionProvider), isNull);
    });

    test('sem sessão não envia nada e falha como não autorizado', () async {
      final (container, sent) = await setUp(
        store: InMemorySessionStore(),
        respond: (_) async => _json(_accessResult(), 200),
      );

      await expectLater(
        container.read(accessGatewayProvider).requestQrAccess(_request),
        _failsWith(AccessFailureReason.unauthorized),
      );

      expect(sent, isEmpty);
    });
  });
}
