import 'dart:async';
import 'dart:convert';

import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/network/api.dart';
import 'package:controle_acesso/core/router/app_router.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/auth/session_store.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'fakes.dart';

void main() {
  // O controller escuta o ciclo de vida do app.
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer containerWith({
    FakeAuthGateway? gateway,
    SessionStore? store,
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

    test('abre com a sessão salva sem esperar o /auth/me', () async {
      final gateway = FakeAuthGateway()..meGate = Completer<void>();
      final container = containerWith(
        gateway: gateway,
        store: InMemorySessionStore(sessionFor()),
      );

      final state = await restored(container);
      expect(state.session?.accessToken, 'jwt-maria');

      // A conferência começa em seguida e não tira a sessão enquanto espera.
      await pumpEventQueue();
      expect(gateway.meTokens, ['jwt-maria']);
      expect(current(container).session?.accessToken, 'jwt-maria');
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

      await restored(container);
      await pumpEventQueue();

      final session = current(container).session;
      expect(gateway.meTokens, ['jwt-maria']);
      expect(session?.user.name, 'Maria S. Lima');
      expect(store.session?.user.name, 'Maria S. Lima');
      expect(container.read(currentSessionProvider), same(session));
    });

    test('sair durante a conferência não traz a sessão de volta', () async {
      final gateway = FakeAuthGateway()..meGate = Completer<void>();
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(gateway: gateway, store: store);
      await restored(container);

      await container.read(sessionControllerProvider.notifier).logout();
      gateway.meGate!.complete();
      await pumpEventQueue();

      expect(current(container).session, isNull);
      expect(store.session, isNull);
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

    test('sessão recusada pelo backend (401) é apagada com aviso', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(
        gateway: FakeAuthGateway(meFailure: AuthFailureReason.unauthorized),
        store: store,
      );

      await restored(container);
      await pumpEventQueue();

      expect(current(container).session, isNull);
      expect(current(container).ended?.reason, SessionEndReason.revoked);
      expect(current(container).ended?.email, maria.email);
      expect(store.session, isNull);
    });

    test('401 síncrono na conferência ainda encerra a sessão', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(
        gateway: _SyncUnauthorizedGateway(),
        store: store,
      );

      await restored(container);
      await pumpEventQueue();

      expect(current(container).ended?.reason, SessionEndReason.revoked);
      expect(store.session, isNull);
    });

    test('sem rede mantém a sessão salva até vencer', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = containerWith(
        gateway: FakeAuthGateway(meFailure: AuthFailureReason.network),
        store: store,
      );

      await restored(container);
      await pumpEventQueue();

      expect(current(container).session?.accessToken, 'jwt-maria');
      expect(store.session, isNotNull);
    });

    test('erro fora do AuthFailure no /auth/me mantém a sessão', () async {
      final store = InMemorySessionStore(sessionFor());
      final container = ProviderContainer.test(
        overrides: [
          sessionStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => fixedNow),
          httpClientProvider.overrideWithValue(
            MockClient((_) async => throw ArgumentError('Unsupported scheme')),
          ),
        ],
      );

      await restored(container);
      await pumpEventQueue();

      expect(current(container).session?.accessToken, 'jwt-maria');
      expect(current(container).ended, isNull);
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

    test('login que responde depois do app fechado não falha', () async {
      final gateway = FakeAuthGateway()..loginGate = Completer<void>();
      final container = containerWith(gateway: gateway);
      await restored(container);

      final login = container
          .read(sessionControllerProvider.notifier)
          .login(request);
      container.dispose();
      gateway.loginGate!.complete();

      await expectLater(login, completes);
    });

    test('Keystore sem gravar ainda deixa entrar, só em memória', () async {
      final store = InMemorySessionStore()..failWrite = true;
      final container = containerWith(store: store);
      await restored(container);

      await container.read(sessionControllerProvider.notifier).login(request);

      expect(current(container).session?.accessToken, 'jwt-maria');
      expect(store.session, isNull);
    });

    test('Keystore sem apagar encerra a sessão e avisa com erro', () async {
      final store = InMemorySessionStore(sessionFor())..failClear = true;
      final container = containerWith(store: store);
      await restored(container);

      await container.read(sessionControllerProvider.notifier).logout();

      expect(current(container).session, isNull);
      expect(current(container).ended?.reason, SessionEndReason.notErased);
      expect(current(container).ended?.email, maria.email);
    });

    test(
      'saída com falha de delete não restaura na abertura seguinte',
      () async {
        final store = SecureSessionStore(_MemoryVault()..failDelete = true);
        final first = containerWith(store: store);
        await restored(first);
        await first.read(sessionControllerProvider.notifier).login(request);
        expect(current(first).session, isNotNull);

        await first.read(sessionControllerProvider.notifier).logout();
        expect(current(first).session, isNull);

        // Reabrir o app: outra sessão do controller sobre o mesmo cofre.
        final reopened = containerWith(store: store);
        final state = await restored(reopened);
        expect(state.session, isNull);
        expect(state.ended, isNull);
      },
    );
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

  group('AuthSession.fromJson', () {
    const valid = {
      'accessToken': 'jwt-maria',
      'expiresAt': '2026-10-27T13:00:00.000Z',
      'user': {
        'id': '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
        'name': 'Maria Souza',
        'email': 'maria.souza@exemplo.com',
        'role': 'RESIDENT',
      },
    };

    test('aceita a sessão que ele mesmo gravou', () {
      final session = AuthSession.fromJson(Map<String, dynamic>.from(valid));
      expect(session.accessToken, 'jwt-maria');
      expect(session.expiresAt, fixedNow.add(const Duration(hours: 1)));
      expect(session.user, isA<AuthUser>());
    });

    test('recusa token vazio, vencimento inválido e usuário incompleto', () {
      final baseUser = Map<String, dynamic>.from(valid['user'] as Map);
      Map<String, dynamic> withUser(Map<String, Object?> patch) => {
        ...valid,
        'user': {...baseUser, ...patch},
      };
      final cases = <String, Map<String, dynamic>>{
        'token vazio': {...valid, 'accessToken': ''},
        'token só com espaços': {...valid, 'accessToken': '  '},
        'token que não é texto': {...valid, 'accessToken': 1},
        'vencimento ausente': {...valid}..remove('expiresAt'),
        'vencimento inválido': {...valid, 'expiresAt': 'amanhã'},
        'vencimento que não é texto': {...valid, 'expiresAt': 1},
        'usuário ausente': {...valid}..remove('user'),
        'usuário que não é objeto': {...valid, 'user': 'maria'},
        'id vazio': withUser({'id': ' '}),
        'nome vazio': withUser({'name': ''}),
        'e-mail vazio': withUser({'email': '  '}),
        'perfil desconhecido': withUser({'role': 'ROOT'}),
        'perfil ausente': withUser({'role': null}),
      };
      for (final MapEntry(key: name, value: json) in cases.entries) {
        expect(
          () => AuthSession.fromJson(json),
          throwsFormatException,
          reason: name,
        );
      }
    });
  });

  group('SecureSessionStore', () {
    const store = SecureSessionStore(FlutterSessionVault());

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

    test('sessão estruturalmente inválida é descartada', () async {
      final expiresAt = fixedNow
          .add(const Duration(hours: 1))
          .toUtc()
          .toIso8601String();
      final corrupted = [
        // Token vazio com vencimento futuro abriria as rotas protegidas.
        {'accessToken': '  ', 'expiresAt': expiresAt, 'user': maria.toJson()},
        // Usuário sem nome quebraria a Home.
        {
          'accessToken': 'jwt-maria',
          'expiresAt': expiresAt,
          'user': {...maria.toJson(), 'name': ''},
        },
        {
          'accessToken': 'jwt-maria',
          'expiresAt': 'ontem',
          'user': maria.toJson(),
        },
      ];
      for (final json in corrupted) {
        FlutterSecureStorage.setMockInitialValues({
          SecureSessionStore.key: jsonEncode(json),
        });

        expect(await store.read(), isNull, reason: '$json');
        expect(
          await const FlutterSecureStorage().read(key: SecureSessionStore.key),
          isNull,
          reason: '$json',
        );
      }
    });

    test('falha ao apagar não devolve a sessão ao reabrir', () async {
      final vault = _MemoryVault()..failDelete = true;
      final store = SecureSessionStore(vault);
      await store.write(sessionFor());

      await store.clear();

      // Nem a leitura, nem uma abertura nova, restauram a sessão.
      expect(await store.read(), isNull);
      final container = containerWith(store: store);
      final state = await restored(container);
      expect(state.session, isNull);
      expect(state.ended, isNull);
    });

    test('sem conseguir gravar, apaga com deleteAll', () async {
      final vault = _MemoryVault();
      final store = SecureSessionStore(vault);
      await store.write(sessionFor());
      vault.failWrite = true;
      vault.failDelete = true;

      await store.clear();

      expect(vault.values, isEmpty);
      expect(await store.read(), isNull);
    });

    test('cofre que não grava nem apaga avisa quem chamou', () async {
      final vault = _MemoryVault();
      final store = SecureSessionStore(vault);
      await store.write(sessionFor());
      vault.failWrite = true;
      vault.failDelete = true;
      vault.failDeleteAll = true;

      await expectLater(store.clear(), throwsA(isA<Exception>()));
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

/// Recusa o token antes de qualquer `await`: a conferência não pode correr
/// na frente do build que entrega a sessão ao estado.
class _SyncUnauthorizedGateway extends FakeAuthGateway {
  @override
  Future<AuthUser> currentUser(String accessToken) =>
      throw const AuthFailure(AuthFailureReason.unauthorized);
}

/// Keystore em memória com falhas simuladas por operação.
class _MemoryVault implements SessionVault {
  final Map<String, String> values = {};

  bool failWrite = false;
  bool failDelete = false;
  bool failDeleteAll = false;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    if (failWrite) throw Exception('keystore');
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    if (failDelete) throw Exception('keystore');
    values.remove(key);
  }

  @override
  Future<void> deleteAll() async {
    if (failDeleteAll) throw Exception('keystore');
    values.clear();
  }
}
