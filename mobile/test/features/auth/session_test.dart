import 'dart:convert';

import 'package:controle_acesso/core/router/app_router.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/auth/session_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  ProviderContainer containerWith({
    FakeAuthGateway? gateway,
    InMemorySessionStore? store,
  }) => ProviderContainer.test(
    overrides: authOverrides(gateway: gateway, store: store),
  );

  group('SessionController', () {
    test('sem sessão salva começa deslogado', () async {
      final container = containerWith();
      expect(await container.read(sessionControllerProvider.future), isNull);
    });

    test(
      'restaura a sessão salva e atualiza o usuário pelo /auth/me',
      () async {
        final gateway = FakeAuthGateway()
          ..meUser = const AuthUser(
            id: 'id',
            name: 'Maria S. Lima',
            email: 'maria.souza@exemplo.com',
            role: UserRole.resident,
          );
        final store = InMemorySessionStore(sessionFor());
        final container = containerWith(gateway: gateway, store: store);

        final session = await container.read(sessionControllerProvider.future);

        expect(gateway.meTokens, ['jwt-maria']);
        expect(session?.user.name, 'Maria S. Lima');
        expect(store.session?.user.name, 'Maria S. Lima');
      },
    );

    test('descarta sessão vencida sem chamar o backend', () async {
      final gateway = FakeAuthGateway();
      final store = InMemorySessionStore(
        sessionFor(validFor: const Duration(seconds: 10)),
      );
      final container = containerWith(gateway: gateway, store: store);

      expect(await container.read(sessionControllerProvider.future), isNull);
      expect(gateway.meTokens, isEmpty);
      expect(store.session, isNull);
    });

    test('descarta sessão recusada pelo backend (401)', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(
        gateway: FakeAuthGateway(meFailure: AuthFailureReason.unauthorized),
        store: store,
      );

      expect(await container.read(sessionControllerProvider.future), isNull);
      expect(store.session, isNull);
    });

    test('sem rede mantém a sessão salva até vencer', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(
        gateway: FakeAuthGateway(meFailure: AuthFailureReason.network),
        store: store,
      );

      final session = await container.read(sessionControllerProvider.future);
      expect(session?.accessToken, 'jwt-maria');
      expect(store.session, isNotNull);
    });

    test('login persiste a sessão e logout apaga', () async {
      final store = InMemorySessionStore();
      final container = containerWith(store: store);
      await container.read(sessionControllerProvider.future);
      final controller = container.read(sessionControllerProvider.notifier);

      await controller.login(
        LoginRequest(email: 'maria.souza@exemplo.com', password: 'x'),
      );
      expect(
        container.read(sessionControllerProvider).value?.user.id,
        maria.id,
      );
      expect(store.session?.accessToken, 'jwt-maria');

      await controller.logout();
      expect(container.read(sessionControllerProvider).value, isNull);
      expect(store.session, isNull);
    });

    test('login recusado não cria sessão', () async {
      final store = InMemorySessionStore();
      final container = containerWith(
        gateway: FakeAuthGateway(loginFailure: AuthFailureReason.unauthorized),
        store: store,
      );
      await container.read(sessionControllerProvider.future);

      await expectLater(
        container
            .read(sessionControllerProvider.notifier)
            .login(LoginRequest(email: 'a@exemplo.com', password: 'x')),
        throwsA(isA<AuthFailure>()),
      );
      expect(container.read(sessionControllerProvider).value, isNull);
      expect(store.session, isNull);
    });
  });

  test('AuthSession vence com a folga de segurança', () {
    final session = sessionFor(validFor: const Duration(minutes: 1));
    expect(session.isExpiredAt(fixedNow), isFalse);
    expect(
      session.isExpiredAt(fixedNow.add(const Duration(seconds: 30))),
      isTrue,
    );
  });

  group('SecureSessionStore', () {
    const store = SecureSessionStore(FlutterSecureStorage());

    test('grava e lê a sessão sem guardar a senha', () async {
      FlutterSecureStorage.setMockInitialValues({});
      await store.write(sessionFor());

      final raw = await const FlutterSecureStorage().read(
        key: SecureSessionStore.key,
      );
      expect(raw, isNot(contains('password')));
      final restored = await store.read();
      expect(restored?.accessToken, 'jwt-maria');
      expect(restored?.expiresAt, sessionFor().expiresAt);
      expect(restored?.user.role, UserRole.resident);
    });

    test('valor corrompido é descartado', () async {
      FlutterSecureStorage.setMockInitialValues({
        SecureSessionStore.key: jsonEncode({'accessToken': 1}),
      });
      expect(await store.read(), isNull);
      expect(
        await const FlutterSecureStorage().read(key: SecureSessionStore.key),
        isNull,
      );
    });
  });

  group('sessionRedirect', () {
    const loading = AsyncLoading<AuthSession?>();
    const loggedOut = AsyncData<AuthSession?>(null);
    final loggedIn = AsyncData<AuthSession?>(sessionFor());

    test('segura na abertura enquanto restaura', () {
      expect(sessionRedirect(loading, AppRoutes.scan), AppRoutes.loading);
      expect(sessionRedirect(loading, AppRoutes.loading), isNull);
    });

    test('deslogado só fica no login', () {
      expect(sessionRedirect(loggedOut, AppRoutes.home), AppRoutes.login);
      expect(sessionRedirect(loggedOut, AppRoutes.scan), AppRoutes.login);
      expect(sessionRedirect(loggedOut, AppRoutes.login), isNull);
    });

    test('logado sai das telas públicas', () {
      expect(sessionRedirect(loggedIn, AppRoutes.login), AppRoutes.home);
      expect(sessionRedirect(loggedIn, AppRoutes.loading), AppRoutes.home);
      expect(sessionRedirect(loggedIn, AppRoutes.scan), isNull);
    });
  });
}
