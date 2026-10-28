import 'dart:convert';

import 'package:controle_acesso/core/router/app_router.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/auth/session_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  // O controller escuta o ciclo de vida do app.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith({
    FakeAuthGateway? gateway,
    InMemorySessionStore? store,
    FakeClock? clock,
  }) => ProviderContainer.test(
    overrides: authOverrides(gateway: gateway, store: store, clock: clock),
  );

  Future<SessionState> restored(ProviderContainer container) =>
      container.read(sessionControllerProvider.future);

  SessionState current(ProviderContainer container) =>
      container.read(sessionControllerProvider).requireValue;

  final request = LoginRequest(
    email: 'maria.souza@exemplo.com',
    password: 'senha-forte-123',
  );

  group('restauração', () {
    test('sem sessão salva começa deslogado e sem aviso', () async {
      final state = await restored(containerWith());
      expect(state.session, isNull);
      expect(state.ended, isNull);
    });

    test('confere a sessão no /auth/me e atualiza o usuário', () async {
      final gateway = FakeAuthGateway()
        ..meUser = const AuthUser(
          id: 'id',
          name: 'Maria S. Lima',
          email: 'maria.souza@exemplo.com',
          role: UserRole.resident,
        );
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(gateway: gateway, store: store);

      final state = await restored(container);

      expect(gateway.meTokens, ['jwt-maria']);
      expect(state.session?.user.name, 'Maria S. Lima');
      expect(store.session?.user.name, 'Maria S. Lima');
      expect(container.read(currentSessionProvider), same(state.session));
    });

    test('sessão vencida é apagada sem chamar o backend', () async {
      final gateway = FakeAuthGateway();
      final store = InMemorySessionStore(
        sessionFor(validFor: const Duration(seconds: 10)),
      );

      final state = await restored(
        containerWith(gateway: gateway, store: store),
      );

      expect(state.session, isNull);
      expect(state.ended?.reason, SessionEndReason.expired);
      expect(state.ended?.email, maria.email);
      expect(gateway.meTokens, isEmpty);
      expect(store.session, isNull);
    });

    test('sessão recusada pelo backend (401) é apagada', () async {
      final store = InMemorySessionStore(sessionFor());

      final state = await restored(
        containerWith(
          gateway: FakeAuthGateway(meFailure: AuthFailureReason.unauthorized),
          store: store,
        ),
      );

      expect(state.session, isNull);
      expect(state.ended?.reason, SessionEndReason.revoked);
      expect(store.session, isNull);
    });

    test('sem rede mantém a sessão salva até vencer', () async {
      final store = InMemorySessionStore(sessionFor());

      final state = await restored(
        containerWith(
          gateway: FakeAuthGateway(meFailure: AuthFailureReason.network),
          store: store,
        ),
      );

      expect(state.session?.accessToken, 'jwt-maria');
      expect(store.session, isNotNull);
    });
  });

  group('login e saída', () {
    test('login persiste a sessão e logout apaga sem aviso', () async {
      final store = InMemorySessionStore();
      final container = containerWith(store: store);
      await restored(container);
      final controller = container.read(sessionControllerProvider.notifier);

      await controller.login(request);
      expect(current(container).session?.user.id, maria.id);
      expect(store.session?.accessToken, 'jwt-maria');

      await controller.logout();
      expect(current(container).session, isNull);
      expect(current(container).ended, isNull);
      expect(store.session, isNull);
    });

    test('login recusado não cria sessão', () async {
      final store = InMemorySessionStore();
      final container = containerWith(
        gateway: FakeAuthGateway(loginFailure: AuthFailureReason.unauthorized),
        store: store,
      );
      await restored(container);

      await expectLater(
        container.read(sessionControllerProvider.notifier).login(request),
        throwsA(isA<AuthFailure>()),
      );
      expect(current(container).session, isNull);
      expect(store.session, isNull);
    });

    test('Keystore sem gravar ainda deixa entrar, só em memória', () async {
      final store = InMemorySessionStore()..failWrite = true;
      final container = containerWith(store: store);
      await restored(container);

      await container.read(sessionControllerProvider.notifier).login(request);

      expect(current(container).session?.accessToken, 'jwt-maria');
      expect(store.session, isNull);
    });

    test('Keystore sem apagar não prende o usuário logado', () async {
      final store = InMemorySessionStore(sessionFor())..failClear = true;
      final container = containerWith(store: store);
      await restored(container);

      await container.read(sessionControllerProvider.notifier).logout();

      expect(current(container).session, isNull);
    });
  });

  group('encerramento pelo backend e pelo relógio', () {
    test('revoke encerra a sessão com aviso', () async {
      final container = containerWith(
        store: InMemorySessionStore(sessionFor()),
      );
      await restored(container);

      await container
          .read(sessionControllerProvider.notifier)
          .revoke('jwt-maria');

      expect(current(container).session, isNull);
      expect(current(container).ended?.reason, SessionEndReason.revoked);
    });

    test('revoke de um token antigo não derruba a sessão nova', () async {
      final container = containerWith(
        store: InMemorySessionStore(sessionFor()),
      );
      await restored(container);

      await container
          .read(sessionControllerProvider.notifier)
          .revoke('jwt-de-outra-sessao');

      expect(current(container).session?.accessToken, 'jwt-maria');
    });

    test('dismissNotice tira o aviso da sessão anterior', () async {
      final container = containerWith(
        store: InMemorySessionStore(
          sessionFor(validFor: const Duration(seconds: 1)),
        ),
      );
      await restored(container);
      expect(current(container).ended, isNotNull);

      container.read(sessionControllerProvider.notifier).dismissNotice();

      expect(current(container).ended, isNull);
    });

    test(
      'ao voltar do segundo plano, token vencido encerra a sessão',
      () async {
        final clock = FakeClock();
        final store = InMemorySessionStore(sessionFor());
        final container = containerWith(store: store, clock: clock);
        await restored(container);

        clock.advance(const Duration(hours: 2));
        final binding = TestWidgetsFlutterBinding.instance;
        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        await pumpEventQueue();

        expect(current(container).session, isNull);
        expect(current(container).ended?.reason, SessionEndReason.expired);
        expect(store.session, isNull);
      },
    );
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
    const loading = AsyncLoading<SessionState>();
    const loggedOut = AsyncData(SessionState.signedOut());
    final loggedIn = AsyncData(SessionState.signedIn(sessionFor()));

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
