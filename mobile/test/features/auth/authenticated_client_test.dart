import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/authenticated_client.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final uri = Uri.parse('https://api.exemplo.com/api/v1/me/authorizations');
  const baseUrl = 'https://api.exemplo.com';

  Future<(ProviderContainer, List<http.Request>)> setUp({
    required int status,
    InMemorySessionStore? store,
  }) async {
    final sent = <http.Request>[];
    final container = ProviderContainer.test(
      overrides: [
        apiBaseUrlProvider.overrideWithValue(baseUrl),
        ...authOverrides(store: store ?? InMemorySessionStore(sessionFor())),
        httpClientProvider.overrideWithValue(
          MockClient((request) async {
            sent.add(request);
            return http.Response('{}', status);
          }),
        ),
      ],
    );
    await container.read(sessionControllerProvider.future);
    return (container, sent);
  }

  SessionState current(ProviderContainer container) =>
      container.read(sessionControllerProvider).requireValue;

  test('envia o Bearer da sessão atual', () async {
    final (container, sent) = await setUp(status: 200);

    final client = container.read(authenticatedClientProvider);
    await client.get(uri);
    // `:443` é a porta padrão do https: continua sendo o mesmo destino.
    final response = await client.get(uri.replace(port: 443));

    expect(response.statusCode, 200);
    expect(sent.map((request) => request.headers['Authorization']), [
      'Bearer jwt-maria',
      'Bearer jwt-maria',
    ]);
    expect(current(container).session, isNotNull);
  });

  test('não envia o Bearer para outra origem', () async {
    final (container, sent) = await setUp(status: 200);
    final client = container.read(authenticatedClientProvider);

    for (final url in [
      // Outro host.
      'https://outro-exemplo.com/api/v1/me/authorizations',
      // Mesmo host, outro esquema.
      'http://api.exemplo.com/api/v1/me/authorizations',
      // Mesmo host, outra porta.
      'https://api.exemplo.com:8443/api/v1/me/authorizations',
    ]) {
      await client.get(Uri.parse(url));
    }

    expect(sent, hasLength(3));
    for (final request in sent) {
      expect(
        request.headers['Authorization'],
        isNull,
        reason: request.url.toString(),
      );
    }
    expect(current(container).session, isNotNull);
  });

  test('401 de outra origem não encerra a sessão', () async {
    final (container, _) = await setUp(status: 401);

    final response = await container
        .read(authenticatedClientProvider)
        .get(Uri.parse('https://outro-exemplo.com/imagem-protegida.png'));
    await pumpEventQueue();

    expect(response.statusCode, 401);
    expect(current(container).session, isNotNull);
    expect(current(container).ended, isNull);
  });

  test('401 encerra a sessão com aviso de sessão encerrada', () async {
    final (container, _) = await setUp(status: 401);

    final response = await container.read(authenticatedClientProvider).get(uri);
    await pumpEventQueue();

    expect(response.statusCode, 401);
    expect(current(container).session, isNull);
    expect(current(container).ended?.reason, SessionEndReason.revoked);
  });

  test('sem sessão a requisição nem sai', () async {
    final (container, sent) = await setUp(
      status: 200,
      store: InMemorySessionStore(),
    );

    await expectLater(
      container.read(authenticatedClientProvider).get(uri),
      throwsA(
        isA<AuthFailure>().having(
          (failure) => failure.reason,
          'reason',
          AuthFailureReason.unauthorized,
        ),
      ),
    );
    expect(sent, isEmpty);
  });
}
