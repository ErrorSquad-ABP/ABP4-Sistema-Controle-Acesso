import 'dart:async';

import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter/services.dart';
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

  void allowStartupLocation(WidgetTester tester) {
    for (final channel in [
      'flutter.baseflow.com/geolocator',
      'flutter.baseflow.com/geolocator_android',
    ]) {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel(channel),
        (call) async => call.method == 'checkPermission' ? 2 : null,
      );
    }
  }

  testWidgets('começa a obter a posição ao abrir o app logado', (tester) async {
    allowStartupLocation(tester);
    final pending = location.pending = Completer<GeoCoordinate>();
    await pumpApp(tester);

    expect(location.positionReads, 1);
    expect(location.permissionRequests, 0);
    expect(access.requests, isEmpty);

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    pending.complete(
      GeoCoordinate(
        latitude: -23.55,
        longitude: -46.63,
        accuracyMeters: 12,
        measuredAt: fixedNow,
      ),
    );
    await tester.pumpAndSettle();

    expect(location.positionReads, 1);
    expect(access.requests.single.position.latitude, -23.55);
  });

  testWidgets('uma posição antiga da abertura não vai no pedido de QR', (
    tester,
  ) async {
    allowStartupLocation(tester);
    location.point = GeoCoordinate(
      latitude: -23.54,
      longitude: -46.63,
      accuracyMeters: 12,
      measuredAt: fixedNow.subtract(const Duration(seconds: 11)),
    );
    await pumpApp(tester);
    expect(location.positionReads, 1);
    location.point = const GeoCoordinate(latitude: -23.55, longitude: -46.64);

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();

    expect(location.positionReads, 2);
    expect(access.requests.single.position.latitude, -23.55);
  });

  testWidgets('usuário logado vai da Home ao scanner', (tester) async {
    await pumpApp(tester);

    expect(find.text('Minhas autorizações'), findsOneWidget);
    expect(find.text('Escanear QR Code'), findsOneWidget);
    expect(find.textContaining('US-29'), findsNothing);

    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    expect(
      find.text('Aponte a câmera para o QR Code exibido no terminal'),
      findsOneWidget,
    );
    expect(find.text('simular leitura'), findsOneWidget);
  });

  testWidgets('acesso liberado: Concluir volta à Home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso liberado'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Minhas autorizações'), findsOneWidget);
    expect(find.text('Acesso liberado'), findsNothing);
  });

  testWidgets('sair durante o GPS impede o pedido de acesso tardio', (
    tester,
  ) async {
    final pending = location.pending = Completer<GeoCoordinate>();
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    expect(find.text('Lendo posição…'), findsOneWidget);

    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();
    expect(find.text('Minhas autorizações'), findsOneWidget);
    pending.complete(location.point);
    await tester.pumpAndSettle();

    expect(access.requests, isEmpty);
    expect(find.text('Minhas autorizações'), findsOneWidget);
  });

  testWidgets('GPS da tela fechada não interfere no scanner reaberto', (
    tester,
  ) async {
    final oldPosition = location.pending = Completer<GeoCoordinate>();
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    await tester.tap(find.text('Voltar'));
    await tester.pumpAndSettle();

    final newPosition = location.pending = Completer<GeoCoordinate>();
    await tester.tap(find.text('Escanear QR Code'));
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
      await tester.tap(find.text('Escanear QR Code'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('simular leitura'));
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget);
      await tester.tap(
        find.text(result == null ? 'Concluir' : 'Voltar ao início'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Minhas autorizações'), findsOneWidget);

      await tester.tap(find.text('Escanear QR Code'));
      await tester.pump();

      expect(find.text(titulo), findsNothing);
      expect(
        find.text('Solicitando permissão de localização…'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(
        find.text('Aponte a câmera para o QR Code exibido no terminal'),
        findsOneWidget,
      );
    });
  }

  testWidgets('acesso negado: volta ao início ou escaneia de novo', (
    tester,
  ) async {
    access.result = deniedResult(DenialReason.authorizationNotStarted);
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Minhas autorizações'), findsOneWidget);

    // Voltar ao scanner depois de um resultado recomeça do zero.
    await tester.tap(find.text('Escanear QR Code'));
    await tester.pumpAndSettle();
    expect(
      find.text('Aponte a câmera para o QR Code exibido no terminal'),
      findsOneWidget,
    );
    expect(find.text('Acesso negado'), findsNothing);
  });
}
