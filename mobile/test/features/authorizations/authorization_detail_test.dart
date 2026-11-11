import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/core/theme/app_colors.dart';
import 'package:controle_acesso/core/theme/theme_mode_provider.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:controle_acesso/features/authorizations/http_authorization_gateway.dart';
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

  Future<void> pumpApp(WidgetTester tester) async {
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
    await tester.pumpAndSettle();
  }

  Future<void> openDetail(WidgetTester tester) async {
    gateway.page = pageOf([authorization()]);
    await pumpApp(tester);
    final card = find.text('Edifício Aurora · Recepção');
    // Com a fonte ampliada o cartão pode estar abaixo da dobra.
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
  }

  testWidgets('cartão da lista abre o detalhe e busca pelo id', (tester) async {
    await openDetail(tester);

    expect(gateway.detailCalls, 1);
    expect(gateway.lastId, authorization().id);
    expect(find.text('Detalhe da autorização'), findsOneWidget);
    // Título do resumo e valor da linha "Local".
    expect(find.text('Edifício Aurora · Recepção'), findsNWidgets(2));
    expect(find.text('Ativa'), findsOneWidget);
    expect(find.text('Local'), findsOneWidget);
    expect(find.text('Período'), findsOneWidget);
    expect(find.textContaining('· 14:00–18:00'), findsOneWidget);
    expect(find.text('Usos restantes'), findsOneWidget);
    expect(find.text('3 de 5 usos restantes'), findsOneWidget);
    expect(find.text('Pessoa'), findsOneWidget);
    expect(find.text('Maria Souza · Visitante'), findsOneWidget);
    expect(find.text('Escanear agora'), findsOneWidget);
  });

  testWidgets('voltar retorna para a lista', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Detalhe da autorização'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas autorizações'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsOneWidget);
    expect(find.text('Escanear agora'), findsNothing);
  });

  testWidgets('mostra o carregando e depois o conteúdo', (tester) async {
    gateway.detailGate = Completer<void>();
    gateway.page = pageOf([authorization()]);
    await pumpApp(tester);

    await tester.tap(find.text('Edifício Aurora · Recepção'));
    // Sem settle: o indicador gira enquanto a resposta não chega.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Carregando a autorização…'), findsOneWidget);
    expect(find.text('Escanear agora'), findsNothing);

    gateway.detailGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Carregando a autorização…'), findsNothing);
    expect(find.text('Escanear agora'), findsOneWidget);
  });

  testWidgets('erro mostra o cartão e permite tentar de novo', (tester) async {
    gateway.detailFailure = AuthorizationFailureReason.unavailable;
    gateway.page = pageOf([authorization()]);
    await pumpApp(tester);
    await tester.tap(find.text('Edifício Aurora · Recepção'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(find.text('Escanear agora'), findsNothing);

    gateway.detailFailure = null;
    gateway.detail = authorization(locationName: 'Edifício Boreal');
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsNothing);
    expect(find.text('Edifício Boreal'), findsNWidgets(2));
    expect(find.text('Escanear agora'), findsOneWidget);
  });

  testWidgets('404 mostra não encontrada e volta pela linha de retorno', (
    tester,
  ) async {
    gateway.detailFailure = AuthorizationFailureReason.notFound;
    gateway.page = pageOf([authorization()]);
    await pumpApp(tester);
    await tester.tap(find.text('Edifício Aurora · Recepção'));
    await tester.pumpAndSettle();

    expect(find.text('Autorização não encontrada'), findsOneWidget);
    expect(
      find.text('Ela pode ter sido removida ou o link não existe mais.'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Escanear agora'), findsNothing);

    await tester.tap(find.text('Detalhe da autorização'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas autorizações'), findsOneWidget);
  });

  testWidgets('Escanear agora abre o scanner', (tester) async {
    await openDetail(tester);

    await tester.tap(find.text('Escanear agora'));
    await tester.pumpAndSettle();

    expect(find.byType(ScannerPage), findsOneWidget);
  });

  testWidgets('detalhe usa o fundo do tema escuro', (tester) async {
    await openDetail(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(App)),
    );
    container.read(themeModeProvider.notifier).set(ThemeMode.dark);
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Detalhe da autorização'));
    expect(
      Theme.of(context).scaffoldBackgroundColor,
      AppPalette.dark.background,
    );
    expect(find.text('Escanear agora'), findsOneWidget);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('detalhe não estoura com fonte ${scale}x em 360x640', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);

      await openDetail(tester);

      expect(tester.takeException(), isNull);
      expect(find.text('Escanear agora'), findsOneWidget);
    });
  }
}
