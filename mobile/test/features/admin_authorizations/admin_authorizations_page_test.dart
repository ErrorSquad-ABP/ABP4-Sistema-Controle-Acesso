import 'dart:async';

import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorization_contract.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorization_form_page.dart';
import 'package:controle_acesso/features/admin_authorizations/admin_authorizations_page.dart';
import 'package:controle_acesso/features/admin_authorizations/http_admin_authorization_gateway.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:controle_acesso/features/locations/http_location_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import '../authorizations/fakes.dart' show authorization, pageOf;
import '../locations/fakes.dart' show FakeLocationGateway, adminUser;
import 'fakes.dart';

void main() {
  late FakeAdminAuthorizationGateway gateway;
  late FakeAdminUserGateway users;
  late FakeLocationGateway places;

  setUp(() {
    gateway = FakeAdminAuthorizationGateway();
    users = FakeAdminUserGateway();
    places = FakeLocationGateway();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    UserRole role = UserRole.admin,
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
          currentSessionProvider.overrideWithValue(
            sessionFor(user: role == UserRole.admin ? adminUser : maria),
          ),
          clockProvider.overrideWithValue(() => fixedNow),
          adminAuthorizationGatewayProvider.overrideWithValue(gateway),
          adminUserGatewayProvider.overrideWithValue(users),
          locationGatewayProvider.overrideWithValue(places),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AdminAuthorizationsPage(),
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

  testWidgets('abre com o cabeçalho de administração e a ação de criar', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);
    expect(find.text('Autorizações'), findsOneWidget);
    expect(find.text('Nova autorização'), findsOneWidget);
    expect(
      tester
          .getSize(find.byKey(const Key('new-admin-authorization-action')))
          .height,
      greaterThanOrEqualTo(48),
    );
    expect(gateway.lastStatus, isNull);
  });

  testWidgets('mostra o carregando e depois o vazio', (tester) async {
    gateway.listGate = Completer<void>();
    await pumpPage(tester, settle: false);

    expect(find.text('Carregando as autorizações…'), findsOneWidget);

    gateway.listGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma autorização'), findsOneWidget);
    expect(
      find.text('As autorizações criadas aparecerão aqui.'),
      findsOneWidget,
    );
  });

  testWidgets('lista o local, a janela, a pessoa e a situação', (tester) async {
    gateway.page = pageOf([
      authorization(
        person: const AuthorizationPerson(
          name: 'João Conceição',
          role: UserRole.visitor,
        ),
      ),
    ]);
    await pumpPage(tester);

    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.textContaining('· 14:00–18:00'), findsOneWidget);
    expect(find.text('João Conceição · Visitante'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    // Só ativa e agendada podem ser canceladas.
    expect(find.text('Cancelar'), findsOneWidget);
  });

  testWidgets('cartão expirado não oferece o cancelamento', (tester) async {
    gateway.page = pageOf([
      authorization(status: AuthorizationStatus.expired),
      authorization(id: 'cancelada', status: AuthorizationStatus.canceled),
    ]);
    await pumpPage(tester);

    expect(find.text('Cancelar'), findsNothing);
  });

  testWidgets('busca filtra por pessoa e por local, sem acento', (
    tester,
  ) async {
    gateway.page = pageOf([
      authorization(locationName: 'Edifício Aurora · Recepção'),
      authorization(
        id: 'norte',
        locationName: 'Portaria Norte',
        person: const AuthorizationPerson(
          name: 'João Conceição',
          role: UserRole.visitor,
        ),
      ),
    ]);
    await pumpPage(tester);

    await tester.enterText(find.byKey(const Key('admin-search')), 'joao');
    await tester.pumpAndSettle();
    expect(find.text('Portaria Norte'), findsOneWidget);
    expect(find.text('Edifício Aurora · Recepção'), findsNothing);

    await tester.enterText(find.byKey(const Key('admin-search')), 'edificio');
    await tester.pumpAndSettle();
    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.text('Portaria Norte'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('admin-search')),
      'inexistente',
    );
    await tester.pumpAndSettle();
    expect(find.text('Nenhuma autorização encontrada'), findsOneWidget);

    await tester.tap(find.byTooltip('Limpar busca'));
    await tester.pumpAndSettle();
    expect(find.text('Portaria Norte'), findsOneWidget);
  });

  testWidgets('filtro de situação busca de novo no servidor', (tester) async {
    await pumpPage(tester);

    // O trilho de chips rola: 'Expiradas' fica fora da largura do aparelho.
    final expired = find.text('Expiradas');
    await tester.ensureVisible(expired);
    await tester.pumpAndSettle();
    await tester.tap(expired);
    await tester.pumpAndSettle();

    expect(gateway.listCalls, 2);
    expect(gateway.lastStatus, AuthorizationStatus.expired);

    gateway.page = pageOf([]);
    final all = find.text('Todas');
    await tester.ensureVisible(all);
    await tester.pumpAndSettle();
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(gateway.lastStatus, isNull);
    expect(find.text('Nenhuma autorização'), findsOneWidget);
  });

  testWidgets('erro mostra o motivo e tenta de novo', (tester) async {
    gateway.listFailure = AdminFailureReason.unavailable;
    await pumpPage(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(
      find.text(
        'O serviço de autorizações está fora do ar. Tente novamente em '
        'instantes.',
      ),
      findsOneWidget,
    );

    gateway.listFailure = null;
    gateway.page = pageOf([authorization(locationName: 'Portaria Norte')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Portaria Norte'), findsOneWidget);
  });

  testWidgets('403 explica que o perfil não administra autorizações', (
    tester,
  ) async {
    gateway.listFailure = AdminFailureReason.forbidden;
    await pumpPage(tester);

    expect(
      find.text('Seu perfil não pode administrar autorizações.'),
      findsOneWidget,
    );
  });

  testWidgets('erro fora do contrato usa a mensagem genérica', (tester) async {
    gateway.listCrash = StateError('boom');
    await pumpPage(tester);

    expect(
      find.text('Não foi possível carregar as autorizações. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('puxar a lista para baixo busca de novo', (tester) async {
    gateway.page = pageOf([authorization()]);
    await pumpPage(tester);
    expect(gateway.listCalls, 1);

    await tester.fling(
      find.byType(CustomScrollView),
      const Offset(0, 400),
      1000,
    );
    await tester.pumpAndSettle();

    expect(gateway.listCalls, 2);
  });

  testWidgets('não-admin vê o motivo em vez da ação de criar', (tester) async {
    await pumpPage(tester, role: UserRole.resident);

    expect(find.text('Nova autorização'), findsNothing);
    expect(
      find.textContaining('Só administradores criam e cancelam'),
      findsOneWidget,
    );
  });

  testWidgets('Nova autorização abre o formulário e voltar retorna', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Nova autorização'));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAuthorizationFormPage), findsOneWidget);
    expect(
      find.textContaining('Escolha a pessoa, o local e a janela'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('back-to-admin-authorizations')));
    await tester.pumpAndSettle();

    expect(find.byType(AdminAuthorizationFormPage), findsNothing);
    expect(find.text('Autorizações'), findsOneWidget);
  });

  testWidgets('cancelar pede o motivo, envia e atualiza a lista', (
    tester,
  ) async {
    gateway.page = pageOf([authorization()]);
    await pumpPage(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(find.text('Cancelar autorização'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar autorização'));
    await tester.pumpAndSettle();
    expect(find.text('Informe o motivo do cancelamento.'), findsOneWidget);
    expect(gateway.canceled, isEmpty);

    await tester.enterText(
      find.byKey(const Key('field-cancel-reason')),
      '  Visita remarcada  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar autorização'));
    await tester.pumpAndSettle();

    expect(gateway.canceled.single.reason, 'Visita remarcada');
    expect(find.text('Cancelar autorização'), findsNothing);
    expect(gateway.listCalls, 2);
    expect(find.text('Autorização cancelada.'), findsOneWidget);

    // Fecha o SnackBar para não deixar o timer pendente.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('cancelamento em conflito (409) explica e mantém o diálogo', (
    tester,
  ) async {
    gateway.page = pageOf([authorization()]);
    gateway.cancelFailure = AdminFailureReason.conflict;
    await pumpPage(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field-cancel-reason')),
      'Motivo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar autorização'));
    await tester.pumpAndSettle();

    expect(find.textContaining('já foi cancelada ou expirou'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(gateway.listCalls, 1);
  });

  testWidgets('403 no cancelamento tem mensagem própria', (tester) async {
    gateway.page = pageOf([authorization()]);
    gateway.cancelFailure = AdminFailureReason.forbidden;
    await pumpPage(tester);

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('field-cancel-reason')),
      'Motivo',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Cancelar autorização'));
    await tester.pumpAndSettle();

    expect(
      find.text('Só administradores podem cancelar autorizações.'),
      findsOneWidget,
    );
  });

  testWidgets('lista, busca e ação não estouram com fonte 2.0x em 360x640', (
    tester,
  ) async {
    gateway.page = pageOf([
      authorization(
        person: const AuthorizationPerson(
          name: 'João Conceição da Silva',
          role: UserRole.visitor,
        ),
      ),
      authorization(
        id: 'outra',
        locationName: 'Edifício Aurora · Garagem',
        status: AuthorizationStatus.scheduled,
      ),
    ]);
    await pumpPage(tester, size: const Size(360, 640), textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('admin-search')), findsOneWidget);
  });

  testWidgets('estado vazio não estoura com fonte 2.0x em 360x640', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(360, 640), textScale: 2);

    expect(find.text('Nenhuma autorização'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
