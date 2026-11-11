import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/admin_users/admin_user_detail_page.dart';
import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/admin_users/http_admin_users_gateway.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAdminUsersGateway users;

  setUp(() {
    users = FakeAdminUsersGateway();
  });

  Future<AdminUser> pumpDetail(
    WidgetTester tester, {
    AdminUser? account,
    UserRole sessionRole = UserRole.admin,
    bool settle = true,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    final target = account ?? userAccount();
    users.page = usersPageOf([target]);

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(
            sessionFor(user: sessionRole == UserRole.admin ? anaAdmin : maria),
          ),
          adminUsersGatewayProvider.overrideWithValue(users),
          clockProvider.overrideWithValue(() => fixedNow),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: AdminUserDetailPage(id: target.id),
        ),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    return target;
  }

  testWidgets('mostra o resumo da conta e os campos preenchidos', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(find.text('Maria Souza'), findsNWidgets(2));
    expect(find.text('maria.souza@exemplo.com'), findsOneWidget);
    expect(find.text('Condômino · conta ativa'), findsOneWidget);
    expect(find.text('DADOS DA CONTA'), findsOneWidget);
    expect(find.text('PERFIL DE ACESSO'), findsOneWidget);
    expect(find.text('EXCLUIR CONTA'), findsOneWidget);
    expect(find.byKey(const Key('field-user-name')), findsOneWidget);
    expect(find.byKey(const Key('switch-active')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('save-user-action'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('delete-user-action'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('salva nome, perfil e situação', (tester) async {
    final account = await pumpDetail(tester);

    await tester.enterText(
      find.byKey(const Key('field-user-name')),
      'Maria Souza Lima',
    );
    await tester.ensureVisible(find.text('Administrador'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Administrador'));
    await tester.ensureVisible(find.byKey(const Key('switch-active')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('switch-active')));
    await tester.pump();
    await tester.ensureVisible(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();

    final (id, request) = users.updates.single;
    expect(id, account.id);
    expect(request.name, 'Maria Souza Lima');
    expect(request.role, UserRole.admin);
    expect(request.active, isFalse);
    expect(find.text('Alterações salvas.'), findsOneWidget);
    expect(find.text('Administrador · conta inativa'), findsOneWidget);
  });

  testWidgets('409 explica que precisa de outro administrador ativo', (
    tester,
  ) async {
    await pumpDetail(tester);
    users.updateFailure = AdminUsersFailureReason.conflict;

    await tester.ensureVisible(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('pelo menos um administrador ativo'),
      findsOneWidget,
    );
  });

  testWidgets('403 explica que o perfil não altera contas', (tester) async {
    await pumpDetail(tester, sessionRole: UserRole.resident);
    users.updateFailure = AdminUsersFailureReason.forbidden;

    await tester.ensureVisible(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Só administradores podem alterar contas.'),
      findsOneWidget,
    );
  });

  testWidgets('falha inesperada não quebra a tela', (tester) async {
    await pumpDetail(tester);
    users.updateFailure = AdminUsersFailureReason.unexpected;

    await tester.ensureVisible(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('save-user-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('Não foi possível salvar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('excluir pede confirmação e só exclui ao confirmar', (
    tester,
  ) async {
    final account = await pumpDetail(tester);

    await tester.ensureVisible(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    expect(find.text('Excluir esta conta?'), findsOneWidget);
    expect(
      find.textContaining('A conta de Maria Souza fica inativa'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(users.deleted, isEmpty);

    await tester.tap(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();

    expect(users.deleted, [account.id]);
  });

  testWidgets('409 do último administrador não exclui a conta', (tester) async {
    await pumpDetail(tester);
    users.deleteFailure = AdminUsersFailureReason.conflict;

    await tester.ensureVisible(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir conta'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não é possível excluir o último administrador'),
      findsOneWidget,
    );
  });

  testWidgets('a própria conta não oferece exclusão', (tester) async {
    await pumpDetail(
      tester,
      account: userAccount(
        id: anaAdmin.id,
        name: anaAdmin.name,
        email: anaAdmin.email,
        role: UserRole.admin,
      ),
    );

    expect(find.byKey(const Key('delete-user-action')), findsNothing);
    expect(find.textContaining('Esta é a sua conta'), findsOneWidget);
  });

  testWidgets('conta que não existe mais mostra o estado próprio', (
    tester,
  ) async {
    users.detailFailure = AdminUsersFailureReason.notFound;
    await pumpDetail(tester);

    expect(find.text('Conta não encontrada'), findsOneWidget);
  });

  testWidgets('403 no detalhe explica o perfil', (tester) async {
    users.detailFailure = AdminUsersFailureReason.forbidden;
    await pumpDetail(tester);

    expect(find.text('Sem permissão'), findsOneWidget);
    expect(
      find.textContaining('Seu perfil não pode abrir esta conta'),
      findsOneWidget,
    );
  });

  testWidgets('erro no detalhe tenta de novo', (tester) async {
    users.detailFailure = AdminUsersFailureReason.unavailable;
    await pumpDetail(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);

    users.detailFailure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('field-user-name')), findsOneWidget);
  });

  testWidgets('não estoura com fonte 2x em 360x640, inclusive no diálogo', (
    tester,
  ) async {
    await pumpDetail(
      tester,
      size: const Size(360, 640),
      textScale: 2,
      account: userAccount(name: 'Maria Aparecida de Souza Oliveira'),
    );

    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const Key('delete-user-action')));
    await tester.pumpAndSettle();

    expect(find.text('Excluir esta conta?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
