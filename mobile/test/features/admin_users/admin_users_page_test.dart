import 'dart:async';

import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/admin_users/access_events_contract.dart';
import 'package:controle_acesso/features/admin_users/admin_user_card.dart';
import 'package:controle_acesso/features/admin_users/admin_user_detail_page.dart';
import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/admin_users/admin_users_page.dart';
import 'package:controle_acesso/features/admin_users/http_access_events_gateway.dart';
import 'package:controle_acesso/features/admin_users/http_admin_users_gateway.dart';
import 'package:controle_acesso/features/admin_users/new_admin_user_page.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart'
    show AccessDecision, DenialReason;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAdminUsersGateway users;
  late FakeAccessEventsGateway events;

  setUp(() {
    users = FakeAdminUsersGateway();
    events = FakeAccessEventsGateway();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    UserRole role = UserRole.admin,
    Size size = const Size(390, 844),
    double textScale = 1,
    bool settle = true,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(
            sessionFor(user: role == UserRole.admin ? anaAdmin : maria),
          ),
          adminUsersGatewayProvider.overrideWithValue(users),
          accessEventsGatewayProvider.overrideWithValue(events),
          clockProvider.overrideWithValue(() => fixedNow),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminUsersPage(),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('abre com o cabeçalho ADMINISTRAÇÃO, abas, busca e ação', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);
    expect(find.text('Usuários'), findsNWidgets(2));
    expect(find.text('Histórico'), findsOneWidget);
    expect(find.byKey(const Key('search-users-field')), findsOneWidget);
    expect(find.byKey(const Key('new-user-action')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('new-user-action'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('search-users-field'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('tab-history'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('mostra o carregando e depois o vazio', (tester) async {
    users.listGate = Completer<void>();
    await pumpPage(tester, settle: false);

    expect(find.text('Carregando as contas…'), findsOneWidget);

    users.listGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conta cadastrada'), findsOneWidget);
    expect(users.lastPageSize, 100);
    expect(users.lastSearch, '');
  });

  testWidgets('lista nome, e-mail, perfil e situação', (tester) async {
    users.page = usersPageOf([
      userAccount(),
      userAccount(
        id: 'outro',
        name: 'Carlos Dias',
        email: 'carlos.dias@exemplo.com',
        role: UserRole.admin,
        active: false,
      ),
    ]);
    await pumpPage(tester);

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(find.text('maria.souza@exemplo.com'), findsOneWidget);
    expect(find.text('Condômino'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Carlos Dias'), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Inativa'), findsOneWidget);
    expect(find.byType(AdminUserCard), findsNWidgets(2));
  });

  testWidgets('o cartão é um alvo de toque com rótulo completo', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    users.page = usersPageOf([userAccount()]);
    await pumpPage(tester);

    expect(
      find.bySemanticsLabel(
        'Maria Souza, maria.souza@exemplo.com, Condômino, conta ativa. '
        'Toque para abrir e editar.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byType(AdminUserCard)).height,
      greaterThanOrEqualTo(48),
    );
    semantics.dispose();
  });

  testWidgets('busca só consulta o servidor ao confirmar', (tester) async {
    users.page = usersPageOf([userAccount()]);
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('search-users-field')),
      'renata',
    );
    await tester.pump();
    expect(users.listCalls, 1);

    await tester.tap(find.byKey(const Key('submit-search-action')));
    await tester.pumpAndSettle();

    expect(users.listCalls, 2);
    expect(users.lastSearch, 'renata');

    await tester.tap(find.byKey(const Key('clear-search-action')));
    await tester.pumpAndSettle();

    expect(users.listCalls, 3);
    expect(users.lastSearch, '');
  });

  testWidgets('busca sem resultado explica o vazio', (tester) async {
    await pumpPage(tester);

    await tester.enterText(
      find.byKey(const Key('search-users-field')),
      'ninguem',
    );
    await tester.tap(find.byKey(const Key('submit-search-action')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma conta encontrada'), findsOneWidget);
    expect(find.textContaining('Tente outro nome'), findsOneWidget);
  });

  testWidgets('erro mostra o motivo e tenta de novo', (tester) async {
    users.listFailure = AdminUsersFailureReason.unavailable;
    await pumpPage(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(
      find.text(
        'O serviço de usuários está fora do ar. Tente novamente em instantes.',
      ),
      findsOneWidget,
    );

    users.listFailure = null;
    users.page = usersPageOf([userAccount(name: 'Renata Alves')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Renata Alves'), findsOneWidget);
  });

  testWidgets('403 explica que o perfil não gerencia contas', (tester) async {
    users.listFailure = AdminUsersFailureReason.forbidden;
    await pumpPage(tester, role: UserRole.resident);

    expect(
      find.text(
        'Seu perfil não pode gerenciar usuários. Peça a um administrador.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('new-user-action')), findsNothing);
    expect(
      find.textContaining('Só administradores gerenciam contas'),
      findsOneWidget,
    );
  });

  testWidgets('erro fora do contrato usa a mensagem genérica', (tester) async {
    users.listCrash = StateError('boom');
    await pumpPage(tester);

    expect(
      find.text('Não foi possível carregar as contas. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('puxar para atualizar busca de novo', (tester) async {
    users.page = usersPageOf([userAccount()]);
    await pumpPage(tester);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 300),
      1000,
    );
    await tester.pumpAndSettle();

    expect(users.listCalls, 2);
  });

  testWidgets('tocar no cartão abre a conta para editar', (tester) async {
    users.page = usersPageOf([userAccount()]);
    await pumpPage(tester);

    await tester.tap(find.byType(AdminUserCard));
    await tester.pumpAndSettle();

    expect(find.byType(AdminUserDetailPage), findsOneWidget);
    expect(find.text('DADOS DA CONTA'), findsOneWidget);
    expect(find.byKey(const Key('field-user-name')), findsOneWidget);
  });

  testWidgets('novo usuário volta para a lista já atualizada', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('new-user-action')));
    await tester.pumpAndSettle();
    expect(find.byType(NewAdminUserPage), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('field-new-user-name')),
      'Renata Alves',
    );
    await tester.enterText(
      find.byKey(const Key('field-new-user-email')),
      'renata.alves@exemplo.com',
    );
    await tester.enterText(
      find.byKey(const Key('field-new-user-password')),
      'senha-forte-123',
    );
    users.page = usersPageOf([userAccount(name: 'Renata Alves')]);
    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    expect(find.byType(NewAdminUserPage), findsNothing);
    expect(users.created.single.name, 'Renata Alves');
    expect(users.created.single.role, UserRole.resident);
    expect(users.listCalls, 2);
    expect(find.text('Renata Alves'), findsOneWidget);
  });

  testWidgets('histórico lista decisão, método, motivo e horário', (
    tester,
  ) async {
    final grantedAt = fixedNow.subtract(const Duration(minutes: 30));
    events.page = eventsPageOf([
      accessEvent(occurredAt: grantedAt, personName: 'Maria Souza'),
      accessEvent(
        id: 'negado',
        occurredAt: fixedNow.subtract(const Duration(hours: 2)),
        method: AccessMethod.nfc,
        decision: AccessDecision.denied,
        reason: DenialReason.outOfRange,
        personName: 'Carlos Dias',
        locationName: 'Garagem',
      ),
    ]);
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    expect(events.listCalls, 1);
    expect(events.lastDecision, isNull);
    expect(events.lastPageSize, 100);
    expect(find.text('Liberado'), findsOneWidget);
    expect(find.text('Negado'), findsOneWidget);
    expect(find.text('QR Code'), findsOneWidget);
    expect(find.text('NFC (aproximação)'), findsOneWidget);
    expect(find.text('Motivo: Fora do raio do local'), findsOneWidget);
    expect(
      find.text(accessEventTimeLabel(occurredAt: grantedAt, now: fixedNow)),
      findsOneWidget,
    );
    expect(find.text('Credencial não identificada'), findsNothing);
  });

  testWidgets('histórico filtra por decisão', (tester) async {
    events.page = eventsPageOf([accessEvent()]);
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('filter-granted')));
    await tester.pumpAndSettle();
    expect(events.lastDecision, AccessDecision.granted);

    await tester.tap(find.byKey(const Key('filter-denied')));
    await tester.pumpAndSettle();
    expect(events.lastDecision, AccessDecision.denied);

    await tester.tap(find.byKey(const Key('filter-all')));
    await tester.pumpAndSettle();
    expect(events.lastDecision, isNull);
  });

  testWidgets('"Mostrar mais" traz a próxima página de contas sem duplicar', (
    tester,
  ) async {
    users.pages[1] = AdminUserPage(
      items: [
        userAccount(),
        userAccount(
          id: 'carlos',
          name: 'Carlos Dias',
          email: 'carlos.dias@exemplo.com',
        ),
      ],
      page: 1,
      pageSize: 2,
      total: 3,
    );
    users.pages[2] = AdminUserPage(
      items: [
        // A API pode repetir um item entre páginas se a lista mudar.
        userAccount(
          id: 'carlos',
          name: 'Carlos Dias',
          email: 'carlos.dias@exemplo.com',
        ),
        userAccount(
          id: 'joana',
          name: 'Joana Reis',
          email: 'joana.reis@exemplo.com',
        ),
      ],
      page: 2,
      pageSize: 2,
      total: 3,
    );
    await pumpPage(tester);

    expect(find.byKey(const Key('load-more-users')), findsOneWidget);
    await tester.ensureVisible(find.text('Mostrar mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar mais'));
    await tester.pumpAndSettle();

    expect(users.lastPage, 2);
    expect(find.byType(AdminUserCard), findsNWidgets(3));
    expect(find.text('Joana Reis'), findsOneWidget);
    expect(find.text('Carlos Dias'), findsOneWidget);
    expect(find.byKey(const Key('load-more-users')), findsNothing);
  });

  testWidgets('erro na segunda página de contas mantém a primeira', (
    tester,
  ) async {
    users.pages[1] = AdminUserPage(
      items: [userAccount()],
      page: 1,
      pageSize: 1,
      total: 2,
    );
    await pumpPage(tester);

    users.listFailure = AdminUsersFailureReason.unavailable;
    await tester.ensureVisible(find.text('Mostrar mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar mais'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(
      find.text(
        'O serviço de usuários está fora do ar. Tente novamente em instantes.',
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('load-more-users')), findsOneWidget);

    // Fecha o SnackBar para não deixar o timer pendente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('histórico carrega a página seguinte sob demanda', (tester) async {
    events.pages[1] = AdminAccessEventPage(
      items: [accessEvent()],
      page: 1,
      pageSize: 1,
      total: 2,
    );
    events.pages[2] = AdminAccessEventPage(
      items: [
        accessEvent(
          id: 'antigo',
          occurredAt: fixedNow.subtract(const Duration(days: 1)),
          personName: 'Carlos Dias',
        ),
      ],
      page: 2,
      pageSize: 1,
      total: 2,
    );
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('load-more-history')), findsOneWidget);
    await tester.ensureVisible(find.text('Mostrar mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar mais'));
    await tester.pumpAndSettle();

    expect(events.lastPage, 2);
    expect(find.text('Carlos Dias'), findsOneWidget);
    expect(find.byKey(const Key('load-more-history')), findsNothing);
  });

  testWidgets('erro na segunda página do histórico mantém a primeira', (
    tester,
  ) async {
    events.pages[1] = AdminAccessEventPage(
      items: [accessEvent(personName: 'Maria Souza')],
      page: 1,
      pageSize: 1,
      total: 2,
    );
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    events.listFailure = AccessEventsFailureReason.unavailable;
    await tester.ensureVisible(find.text('Mostrar mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostrar mais'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
    expect(
      find.text(
        'O serviço de histórico está fora do ar. Tente novamente em instantes.',
      ),
      findsOneWidget,
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('histórico vazio e com erro tem estados claros', (tester) async {
    await pumpPage(tester);
    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    expect(find.text('Nenhum acesso encontrado'), findsOneWidget);
    expect(
      find.text('As tentativas de acesso aparecerão aqui.'),
      findsOneWidget,
    );

    events.listFailure = AccessEventsFailureReason.forbidden;
    await tester.tap(find.byKey(const Key('filter-granted')));
    await tester.pumpAndSettle();

    expect(
      find.text('Seu perfil não pode ver o histórico de acessos.'),
      findsOneWidget,
    );

    events.listFailure = null;
    events.page = eventsPageOf([accessEvent()]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('lista não estoura com fonte ${scale}x em 360x640', (
      tester,
    ) async {
      users.page = usersPageOf([
        userAccount(name: 'Maria Aparecida de Souza Oliveira'),
        userAccount(
          id: 'outro',
          name: 'Carlos Dias',
          role: UserRole.admin,
          active: false,
        ),
      ]);
      await pumpPage(tester, size: const Size(360, 640), textScale: scale);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('histórico não estoura com fonte 2x em 360x640', (tester) async {
    events.page = eventsPageOf([
      accessEvent(
        decision: AccessDecision.denied,
        reason: DenialReason.authorizationNotStarted,
        personName: 'Maria Aparecida de Souza Oliveira',
        locationName: 'Edifício Aurora · Recepção principal',
      ),
    ]);
    await pumpPage(tester, size: const Size(360, 640), textScale: 2);

    await tester.tap(find.byKey(const Key('tab-history')));
    await tester.pumpAndSettle();

    // Com a fonte ampliada o cartão fica abaixo da dobra: rolar até ele prova
    // que o conteúdo continua alcançável, sem estouro.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(find.text('Negado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('vazio não estoura com fonte 2x em 360x640', (tester) async {
    await pumpPage(tester, size: const Size(360, 640), textScale: 2);

    expect(find.text('Nenhuma conta cadastrada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
