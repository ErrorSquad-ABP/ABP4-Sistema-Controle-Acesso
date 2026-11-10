import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAccessGateway access;
  late FakeLocationGateway location;

  setUp(() {
    access = FakeAccessGateway();
    location = FakeLocationGateway();
  });

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(store: InMemorySessionStore(sessionFor())),
          locationGatewayProvider.overrideWithValue(location),
          qrScannerGatewayProvider.overrideWithValue(FakeQrScannerGateway()),
          accessGatewayProvider.overrideWithValue(access),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('usuário logado vai da Home ao scanner', (tester) async {
    await pumpApp(tester);

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);
    expect(find.textContaining('US-29'), findsNothing);

    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('simular leitura'), findsOneWidget);
  });

  testWidgets('acesso liberado: Concluir volta à Home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso liberado'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Acesso liberado'), findsNothing);
  });

  testWidgets('sair durante o GPS impede o pedido de acesso tardio', (
    tester,
  ) async {
    final pending = location.pending = Completer<GeoCoordinate>();
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    expect(find.text('Lendo posição…'), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);
    pending.complete(location.point);
    await tester.pumpAndSettle();

    expect(access.requests, isEmpty);
    expect(find.text('Início'), findsOneWidget);
  });

  testWidgets('GPS da tela fechada não interfere no scanner reaberto', (
    tester,
  ) async {
    final oldPosition = location.pending = Completer<GeoCoordinate>();
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    final newPosition = location.pending = Completer<GeoCoordinate>();
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    oldPosition.complete(location.point);
    await tester.pump();
    expect(find.text('Lendo posição…'), findsOneWidget);
    expect(access.requests, isEmpty);

    newPosition.complete(location.point);
    await tester.pumpAndSettle();
    expect(access.requests, hasLength(1));
    expect(find.text('Acesso liberado'), findsOneWidget);
  });

  // `pumpAndSettle` esconderia um resultado antigo visível só no primeiro quadro.
  for (final (nome, result, titulo) in [
    ('liberado', null, 'Acesso liberado'),
    ('negado', DenialReason.outOfRange, 'Acesso negado'),
  ]) {
    testWidgets('reabrir o scanner depois de "$nome" não mostra o resultado '
        'anterior no primeiro quadro', (tester) async {
      if (result != null) access.result = deniedResult(result);
      await pumpApp(tester);
      await tester.tap(find.text('Escanear QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('simular leitura'));
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget);
      await tester.tap(
        find.text(result == null ? 'Concluir' : 'Voltar ao início'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsOneWidget);

      await tester.tap(find.text('Escanear QR'));
      await tester.pump();

      expect(find.text(titulo), findsNothing);
      expect(
        find.text('Solicitando permissão de localização…'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    });
  }

  testWidgets('acesso negado: volta ao início ou escaneia de novo', (
    tester,
  ) async {
    access.result = deniedResult(DenialReason.authorizationNotStarted);
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);

    // Voltar ao scanner depois de um resultado recomeça do zero.
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('Acesso negado'), findsNothing);
  });
}
