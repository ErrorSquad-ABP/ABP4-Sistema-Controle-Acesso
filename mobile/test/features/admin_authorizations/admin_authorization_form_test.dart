import 'dart:async';

import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorization_contract.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorization_form_page.dart';
import 'package:controle_acesso/features/admin_authorizations/http_admin_authorization_gateway.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/locations/http_location_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import '../locations/fakes.dart'
    show FakeLocationGateway, adminUser, location, pageOf;
import 'fakes.dart';

/// Abre o formulário por push, como a tela de administração faz, para conferir
/// que o sucesso volta para a rota anterior.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (context) => const AdminAuthorizationFormPage(),
              ),
            ),
            child: const Text('abrir formulario'),
          ),
        ),
      ),
    );
  }
}

void main() {
  late FakeAdminAuthorizationGateway gateway;
  late FakeAdminUserGateway users;
  late FakeLocationGateway places;

  setUp(() {
    gateway = FakeAdminAuthorizationGateway();
    users = FakeAdminUserGateway();
    places = FakeLocationGateway();
    // Um local com descrição e outro sem, para conferir o filtro da folha.
    places.page = pageOf([
      location(),
      location(id: 'norte', name: 'Portaria Norte', description: null),
    ]);
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    bool settle = true,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(sessionFor(user: adminUser)),
          clockProvider.overrideWithValue(() => fixedNow),
          adminAuthorizationGatewayProvider.overrideWithValue(gateway),
          adminUserGatewayProvider.overrideWithValue(users),
          locationGatewayProvider.overrideWithValue(places),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const _Host()),
      ),
    );
    await tester.tap(find.text('abrir formulario'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Future<void> selectPerson(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('field-person')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Maria Souza'));
    await tester.pumpAndSettle();
  }

  Future<void> selectPlace(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('field-place')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edifício Aurora · Recepção'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra os campos e a ação de criar', (tester) async {
    await pumpForm(tester);

    expect(find.text('Nova autorização'), findsOneWidget);
    expect(find.text('Pessoa'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Início da janela'), findsOneWidget);
    expect(find.text('Fim da janela'), findsOneWidget);
    expect(find.text('MÁXIMO DE USOS'), findsOneWidget);
    expect(find.text('Criar autorização'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('save-admin-authorization-action')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(find.byKey(const Key('back-to-admin-authorizations')))
          .height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('sem pessoa e local não chama a API e mostra os erros', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pumpAndSettle();

    expect(find.text('Escolha a pessoa.'), findsOneWidget);
    expect(find.text('Escolha o local.'), findsOneWidget);
    expect(gateway.created, isEmpty);
  });

  testWidgets('máximo de usos fica entre 1 e 1000', (tester) async {
    await pumpForm(tester);

    for (final value in ['0', '1001']) {
      await tester.enterText(find.byKey(const Key('field-max-uses')), value);
      await tester.tap(
        find.byKey(const Key('save-admin-authorization-action')),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('O máximo de usos deve ficar entre 1 e 1000.'),
        findsOneWidget,
      );
    }
    expect(gateway.created, isEmpty);
  });

  testWidgets('seletor de pessoa busca no servidor e devolve a escolhida', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('field-person')));
    await tester.pumpAndSettle();

    expect(users.calls, 1);
    expect(users.lastSearch, isEmpty);
    expect(users.lastActive, isTrue);
    expect(
      find.text('Maria Souza · maria.souza@exemplo.com · Visitante'),
      findsOneWidget,
    );

    await tester.enterText(find.byKey(const Key('picker-search')), 'jo');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();
    expect(users.lastSearch, 'jo');

    await tester.tap(find.text('Maria Souza'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('picker-search')), findsNothing);
    // O campo passa a mostrar a pessoa escolhida.
    expect(find.text('Maria Souza'), findsOneWidget);
  });

  testWidgets('seletor de local carrega os ativos e filtra aqui', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('field-place')));
    await tester.pumpAndSettle();

    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.text('Portaria Norte'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('picker-search')), 'norte');
    await tester.tap(find.byTooltip('Buscar'));
    await tester.pumpAndSettle();

    expect(find.text('Portaria Norte'), findsOneWidget);
    expect(find.text('Edifício Aurora · Recepção'), findsNothing);
  });

  testWidgets('início da janela passa por data e hora e atualiza o campo', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('field-window-start')));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);

    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(find.byType(DatePickerDialog), findsNothing);
    expect(find.byType(TimePickerDialog), findsNothing);
    expect(find.textContaining('/2026 · '), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cria com pessoa, local, janela padrão e usos', (tester) async {
    await pumpForm(tester);

    await selectPerson(tester);
    await selectPlace(tester);
    await tester.enterText(find.byKey(const Key('field-max-uses')), '5');
    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pumpAndSettle();

    final request = gateway.created.single;
    expect(request.userId, '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11');
    expect(request.locationId, 'c1f2a3b4-1111-4222-8333-944455556666');
    expect(request.maxUses, 5);
    // Janela padrão do formulário: agora até daqui a 2 h.
    expect(request.startsAt, fixedNow);
    expect(request.endsAt, fixedNow.add(const Duration(hours: 2)));
    // Sucesso volta para a tela anterior.
    expect(find.text('abrir formulario'), findsOneWidget);
  });

  for (final (reason, message) in [
    (
      AdminFailureReason.unprocessable,
      'A pessoa ou o local escolhidos não existem mais. Escolha de novo.',
    ),
    (AdminFailureReason.forbidden, 'Só administradores criam autorizações.'),
    (
      AdminFailureReason.invalidRequest,
      'O servidor recusou os dados da autorização. Confira a janela e o '
          'máximo de usos.',
    ),
  ]) {
    testWidgets('${reason.name} mostra a mensagem própria e mantém a tela', (
      tester,
    ) async {
      gateway.createFailure = reason;
      await pumpForm(tester);

      await selectPerson(tester);
      await selectPlace(tester);
      await tester.tap(
        find.byKey(const Key('save-admin-authorization-action')),
      );
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(AdminAuthorizationFormPage), findsOneWidget);
    });
  }

  testWidgets('criando mostra o progresso e ignora toques repetidos', (
    tester,
  ) async {
    gateway.createGate = Completer<void>();
    await pumpForm(tester);

    await selectPerson(tester);
    await selectPlace(tester);
    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pump();

    expect(find.text('Criando…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pump();
    expect(gateway.created, hasLength(1));

    gateway.createGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('abrir formulario'), findsOneWidget);
  });

  testWidgets('erro fora do contrato não quebra o formulário', (tester) async {
    gateway.createCrash = StateError('boom');
    await pumpForm(tester);

    await selectPerson(tester);
    await selectPlace(tester);
    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível criar a autorização. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('falha ao carregar pessoas oferece tentar de novo na folha', (
    tester,
  ) async {
    users.failure = AdminFailureReason.unavailable;
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('field-person')));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar as pessoas.'), findsOneWidget);

    users.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza'), findsOneWidget);
  });

  testWidgets('formulário não estoura com fonte 2.0x em 360x640', (
    tester,
  ) async {
    await pumpForm(tester, size: const Size(360, 640), textScale: 2);

    await tester.tap(find.byKey(const Key('save-admin-authorization-action')));
    await tester.pumpAndSettle();

    expect(find.text('Escolha a pessoa.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
