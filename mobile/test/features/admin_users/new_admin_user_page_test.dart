import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/admin_users/http_admin_users_gateway.dart';
import 'package:controle_acesso/features/admin_users/new_admin_user_page.dart';
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

  Future<void> pumpPage(
    WidgetTester tester, {
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
          currentSessionProvider.overrideWithValue(sessionFor(user: anaAdmin)),
          adminUsersGatewayProvider.overrideWithValue(users),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NewAdminUserPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester, {
    String name = 'Renata Alves',
    String email = 'renata.alves@exemplo.com',
    String password = 'senha-forte-123',
  }) async {
    await tester.enterText(find.byKey(const Key('field-new-user-name')), name);
    await tester.enterText(
      find.byKey(const Key('field-new-user-email')),
      email,
    );
    await tester.enterText(
      find.byKey(const Key('field-new-user-password')),
      password,
    );
  }

  testWidgets('abre com os campos, perfis e ação de criar', (tester) async {
    await pumpPage(tester);

    expect(find.text('Novo usuário'), findsOneWidget);
    expect(find.byKey(const Key('field-new-user-name')), findsOneWidget);
    expect(find.byKey(const Key('field-new-user-email')), findsOneWidget);
    expect(find.byKey(const Key('field-new-user-password')), findsOneWidget);
    expect(find.text('Administrador'), findsOneWidget);
    expect(find.text('Condômino'), findsOneWidget);
    expect(find.text('Visitante'), findsOneWidget);
    expect(find.byKey(const Key('create-user-action')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('create-user-action'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('cada perfil é um alvo com descrição para o leitor de tela', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpPage(tester);

    expect(
      find.bySemanticsLabel(
        'Administrador. Gerencia pessoas, locais e acessos.',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        'Condômino. Mora no condomínio e recebe autorizações.',
      ),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('valida os campos antes de enviar', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome da pessoa.'), findsOneWidget);
    expect(find.text('Informe seu e-mail.'), findsOneWidget);
    expect(find.text('Crie uma senha para a pessoa.'), findsOneWidget);
    expect(users.created, isEmpty);
  });

  testWidgets('recusa e-mail inválido e senha curta', (tester) async {
    await pumpPage(tester);
    await fillForm(tester, email: 'renata-sem-arroba', password: '1234567');

    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    expect(find.textContaining('e-mail válido'), findsOneWidget);
    expect(find.textContaining('pelo menos 8 caracteres'), findsOneWidget);
    expect(users.created, isEmpty);
  });

  testWidgets('cria a conta com o perfil escolhido', (tester) async {
    await pumpPage(tester);
    await fillForm(tester);
    await tester.ensureVisible(find.text('Visitante'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Visitante'));
    await tester.pump();

    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    final request = users.created.single;
    expect(request.name, 'Renata Alves');
    expect(request.email, 'renata.alves@exemplo.com');
    expect(request.password, 'senha-forte-123');
    expect(request.role, UserRole.visitor);
  });

  testWidgets('alterna a visibilidade da senha com rótulo', (tester) async {
    await pumpPage(tester);

    expect(find.byTooltip('Mostrar senha'), findsOneWidget);
    await tester.tap(find.byKey(const Key('toggle-password-visibility')));
    await tester.pump();
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);
  });

  testWidgets('409 explica que o e-mail já está em uso', (tester) async {
    await pumpPage(tester);
    users.createFailure = AdminUsersFailureReason.conflict;
    await fillForm(tester);

    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Já existe uma conta com este e-mail. Use outro e-mail.'),
      findsOneWidget,
    );
  });

  testWidgets('403 explica que o perfil não cria contas', (tester) async {
    await pumpPage(tester);
    users.createFailure = AdminUsersFailureReason.forbidden;
    await fillForm(tester);

    await tester.tap(find.byKey(const Key('create-user-action')));
    await tester.pumpAndSettle();

    expect(find.text('Só administradores podem criar contas.'), findsOneWidget);
  });

  testWidgets('não estoura com fonte 2x em 360x640', (tester) async {
    await pumpPage(tester, size: const Size(360, 640), textScale: 2);

    expect(tester.takeException(), isNull);

    await tester.drag(find.byType(ListView), const Offset(0, -900));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
