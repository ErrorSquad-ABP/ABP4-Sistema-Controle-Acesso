import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:controle_acesso/features/authorizations/http_authorization_gateway.dart';
import 'package:controle_acesso/features/authorizations/authorizations_page.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:controle_acesso/features/scanner/scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import '../scanner/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAuthorizationGateway gateway;

  setUp(() {
    gateway = FakeAuthorizationGateway();
  });

  Future<void> pumpApp(WidgetTester tester, {bool settle = true}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(store: InMemorySessionStore(sessionFor())),
          authorizationGatewayProvider.overrideWithValue(gateway),
          locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
          qrScannerGatewayProvider.overrideWithValue(FakeQrScannerGateway()),
        ],
        child: const App(),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Finder filterOption(String label) => find.text(label).first;
  Finder navDestination(String label) => find.text(label).last;

  testWidgets('abre na tela de autorizações com a ação e as três abas', (
    tester,
  ) async {
    await pumpApp(tester);

    expect(find.text('SEU ACESSO'), findsOneWidget);
    expect(find.text('Minhas autorizações'), findsOneWidget);
    expect(find.text('Ativas'), findsOneWidget);
    expect(find.text('Histórico'), findsNWidgets(2)); // filtro + aba
    expect(find.text('Escanear QR Code'), findsOneWidget);
    expect(find.text('Autorizações'), findsOneWidget);
    expect(find.text('Perfil'), findsOneWidget);
  });

  testWidgets('mostra o carregando e depois o vazio', (tester) async {
    gateway.gate = Completer<void>();
    await pumpApp(tester, settle: false);

    expect(find.text('Carregando suas autorizações…'), findsOneWidget);

    gateway.gate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma autorização ainda'), findsOneWidget);
    expect(
      find.text('Suas liberações aparecerão aqui assim que forem criadas.'),
      findsOneWidget,
    );
  });

  testWidgets('erro mostra o cartão do Figma e tenta de novo', (tester) async {
    gateway.failure = AuthorizationFailureReason.unavailable;
    await pumpApp(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    gateway.failure = null;
    gateway.page = pageOf([authorization()]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsNothing);
    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
  });

  testWidgets('lista o local, a janela, os usos e a situação', (tester) async {
    gateway.page = pageOf([authorization()]);
    await pumpApp(tester);

    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.textContaining('· 14:00–18:00'), findsOneWidget);
    expect(find.text('3 de 5 usos restantes'), findsOneWidget);
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.byIcon(Icons.apartment_outlined), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
  });

  testWidgets('filtro Ativas/Histórico separa as situações', (tester) async {
    gateway.page = pageOf([
      authorization(id: 'ativa', locationName: 'Ativa Ltda'),
      authorization(
        id: 'expirada',
        locationName: 'Expirada Ltda',
        status: AuthorizationStatus.expired,
      ),
      authorization(
        id: 'cancelada',
        locationName: 'Cancelada Ltda',
        status: AuthorizationStatus.canceled,
      ),
    ]);
    await pumpApp(tester);

    // O Figma mostra uma expirada na aba Ativas.
    expect(find.text('Ativa Ltda'), findsOneWidget);
    expect(find.text('Expirada Ltda'), findsOneWidget);

    await tester.tap(filterOption('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Ativa Ltda'), findsNothing);
    expect(find.text('Expirada Ltda'), findsOneWidget);
    expect(find.text('Cancelada Ltda'), findsOneWidget);
    expect(find.text('Expirada'), findsOneWidget);
    expect(find.text('Cancelada'), findsOneWidget);
  });

  testWidgets('aba Histórico abre a mesma lista já filtrada', (tester) async {
    gateway.page = pageOf([
      authorization(id: 'ativa', locationName: 'Ativa Ltda'),
      authorization(
        id: 'expirada',
        locationName: 'Expirada Ltda',
        status: AuthorizationStatus.expired,
      ),
    ]);
    await pumpApp(tester);

    await tester.tap(navDestination('Histórico'));
    await tester.pumpAndSettle();

    expect(find.text('Expirada Ltda'), findsOneWidget);
    expect(find.text('Ativa Ltda'), findsNothing);

    await tester.tap(navDestination('Autorizações'));
    await tester.pumpAndSettle();

    expect(find.text('Ativa Ltda'), findsOneWidget);
  });

  testWidgets('aba Perfil mostra a conta e sai pelo login', (tester) async {
    await pumpApp(tester);

    await tester.tap(navDestination('Perfil'));
    await tester.pumpAndSettle();

    expect(find.text('Meu perfil'), findsOneWidget);
    expect(find.text('Maria Souza · Condômino'), findsOneWidget);
    expect(find.text('maria.souza@exemplo.com'), findsOneWidget);

    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sair da conta'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Sair'));
    await tester.pumpAndSettle();

    expect(find.text('Bem-vindo de volta'), findsOneWidget);
  });

  testWidgets('Escanear QR Code abre o scanner', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerPage), findsOneWidget);
  });

  testWidgets('o filtro fica na tela ao trocar de aba e voltar', (
    tester,
  ) async {
    gateway.page = pageOf([
      authorization(id: 'ativa', locationName: 'Ativa Ltda'),
      authorization(
        id: 'expirada',
        locationName: 'Expirada Ltda',
        status: AuthorizationStatus.expired,
      ),
    ]);
    await pumpApp(tester);

    await tester.tap(filterOption('Histórico'));
    await tester.pumpAndSettle();
    expect(find.text('Expirada Ltda'), findsOneWidget);

    await tester.tap(navDestination('Perfil'));
    await tester.pumpAndSettle();

    await tester.tap(navDestination('Autorizações'));
    await tester.pumpAndSettle();

    // A aba guarda o estado: volta no Histórico, não em Ativas.
    expect(find.text('Expirada Ltda'), findsOneWidget);
  });

  testWidgets('sem usuário na sessão a tela não tenta buscar', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(store: InMemorySessionStore()),
          authorizationGatewayProvider.overrideWithValue(gateway),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AuthorizationsPage), findsNothing);
    expect(gateway.calls, 0);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('lista e erros não estouram com fonte ${scale}x em 360x640', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      gateway.page = pageOf([
        authorization(),
        authorization(
          id: 'expirada',
          locationName: 'Edifício Aurora · Recepção',
          status: AuthorizationStatus.expired,
        ),
      ]);
      await pumpApp(tester);

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('erro não estoura com fonte 1.3x em 360x640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    gateway.failure = AuthorizationFailureReason.network;
    await pumpApp(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
