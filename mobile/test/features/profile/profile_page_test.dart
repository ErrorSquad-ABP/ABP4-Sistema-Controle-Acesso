import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/theme/theme_mode_provider.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/profile/http_profile_gateway.dart';
import 'package:controle_acesso/features/profile/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  Future<void> pumpProfile(
    WidgetTester tester, {
    FakeProfileGateway? gateway,
    FakeAuthGateway? auth,
    InMemorySessionStore? store,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(
            gateway: auth,
            store: store ?? InMemorySessionStore(sessionFor()),
          ),
          profileGatewayProvider.overrideWithValue(
            gateway ?? FakeProfileGateway(),
          ),
        ],
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: const Locale('pt', 'BR'),
            supportedLocales: const [Locale('pt', 'BR')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ref.watch(themeModeProvider),
            home: const ProfilePage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('mostra nome, papel e e-mail da sessão', (tester) async {
    await pumpProfile(tester);

    expect(find.text('SUA CONTA'), findsOneWidget);
    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Maria Souza · Condômino'), findsOneWidget);
    expect(find.text('maria.souza@exemplo.com'), findsOneWidget);
    // Iniciais no cabeçalho e no cartão.
    expect(find.text('MS'), findsNWidgets(2));
  });

  testWidgets('seletor de tema troca para o escuro e atualiza a legenda', (
    tester,
  ) async {
    await pumpProfile(tester);
    expect(
      Theme.of(tester.element(find.text('APARÊNCIA'))).brightness,
      Brightness.light,
    );

    await tester.tap(find.text('Escuro'));
    await tester.pumpAndSettle();

    expect(
      Theme.of(tester.element(find.text('APARÊNCIA'))).brightness,
      Brightness.dark,
    );
    expect(
      find.text(
        'Escuro selecionado. Você pode alterar o tema a qualquer momento.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('editar nome faz o PATCH, mostra sucesso e atualiza a sessão', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    final store = InMemorySessionStore(sessionFor());
    await pumpProfile(tester, gateway: gateway, store: store);

    await tester.tap(find.text('Editar nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Maria Souza Lima  ');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.names, ['Maria Souza Lima']);
    expect(find.text('Maria Souza Lima · Condômino'), findsOneWidget);
    expect(find.text('Nome atualizado.'), findsOneWidget);
    expect(store.session?.user.name, 'Maria Souza Lima');
  });

  testWidgets('nome com menos de 2 caracteres não chega ao servidor', (
    tester,
  ) async {
    final gateway = FakeProfileGateway();
    await pumpProfile(tester, gateway: gateway);

    await tester.tap(find.text('Editar nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), ' A ');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(gateway.names, isEmpty);
    expect(find.textContaining('ao menos 2 caracteres'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });

  testWidgets('erro do PATCH fica no diálogo com o texto digitado', (
    tester,
  ) async {
    final gateway = FakeProfileGateway(
      failure: AuthFailureReason.invalidRequest,
    );
    await pumpProfile(tester, gateway: gateway);

    await tester.tap(find.text('Editar nome'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Maria Souza Lima');
    await tester.tap(find.widgetWithText(FilledButton, 'Salvar'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(
      find.text('Confira o nome informado e tente de novo.'),
      findsOneWidget,
    );
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    expect(field.controller?.text, 'Maria Souza Lima');
  });

  testWidgets('pull-to-refresh traz o usuário atualizado de GET /auth/me', (
    tester,
  ) async {
    final auth = FakeAuthGateway()
      ..meUser = const AuthUser(
        id: '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
        name: 'Maria Souza Lima',
        email: 'maria.souza@exemplo.com',
        role: UserRole.resident,
      );
    await pumpProfile(tester, auth: auth);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza Lima · Condômino'), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
  });

  testWidgets('refresh sem servidor avisa e mantém o perfil na tela', (
    tester,
  ) async {
    final auth = FakeAuthGateway(meFailure: AuthFailureReason.unavailable);
    await pumpProfile(tester, auth: auth);

    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pumpAndSettle();

    expect(find.text('Maria Souza · Condômino'), findsOneWidget);
    expect(
      find.text('Não foi possível atualizar seus dados. Tente novamente.'),
      findsOneWidget,
    );
    final banner = tester.widget<FeedbackBanner>(find.byType(FeedbackBanner));
    expect(banner.tone, FeedbackTone.warning);
  });

  testWidgets('sair da conta pede confirmação e encerra a sessão', (
    tester,
  ) async {
    final store = InMemorySessionStore(sessionFor());
    await pumpProfile(tester, store: store);

    // A lista só constrói o que está na tela: rola até os atalhos.
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    expect(store.session, isNotNull);

    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    // Após sair, o Perfil mostra o indicador (o router levaria ao login) e o
    // `pumpAndSettle` nunca terminaria.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(store.session, isNull);
    expect(find.text('Meu perfil'), findsNothing);
  });

  testWidgets('alvos de toque têm ao menos 48dp', (tester) async {
    await pumpProfile(tester);

    expect(
      tester.getSize(find.widgetWithText(TextButton, 'Editar nome')).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester
          .getSize(
            find.ancestor(
              of: find.text('Claro'),
              matching: find.byType(InkWell),
            ),
          )
          .height,
      greaterThanOrEqualTo(48),
    );

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    final logoutRow = find.ancestor(
      of: find.text('Sair da conta'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(logoutRow).height, greaterThanOrEqualTo(48));
  });

  testWidgets('não estoura com fonte 1.3 em 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await pumpProfile(tester);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Editar nome'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
