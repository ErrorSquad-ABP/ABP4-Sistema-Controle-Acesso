import 'dart:async';

import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:controle_acesso/features/scanner/scanner_controller.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:controle_acesso/features/scanner/scanner_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeLocationGateway location;
  late FakeQrScannerGateway scanner;
  late FakeAccessGateway access;
  late FakeRequestIds ids;

  // Instrução do Figma para a tela de leitura.
  final instruction = find.text(
    'Aponte a câmera para o QR Code exibido no terminal',
  );

  setUp(() {
    location = FakeLocationGateway();
    scanner = FakeQrScannerGateway();
    access = FakeAccessGateway();
    ids = FakeRequestIds();
  });

  Future<void> pumpScanner(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationGatewayProvider.overrideWithValue(location),
          qrScannerGatewayProvider.overrideWithValue(scanner),
          accessGatewayProvider.overrideWithValue(access),
          requestIdFactoryProvider.overrideWithValue(ids.call),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt', 'BR'),
          supportedLocales: const [Locale('pt', 'BR')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          home: const ScannerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> scan(WidgetTester tester) async {
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
  }

  testWidgets('pede a permissão antes de mostrar a câmera', (tester) async {
    final pending = Completer<ScannerPermission>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationGatewayProvider.overrideWithValue(_SlowLocation(pending)),
          qrScannerGatewayProvider.overrideWithValue(scanner),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const ScannerPage()),
      ),
    );
    await tester.pump();

    expect(find.text('Solicitando permissão de localização…'), findsOneWidget);
    expect(scanner.detect, isNull);

    pending.complete(ScannerPermission.granted);
    await tester.pumpAndSettle();

    expect(instruction, findsOneWidget);
    expect(scanner.detect, isNotNull);
  });

  testWidgets('explica que a posição é enviada e a regra dos 100 m', (
    tester,
  ) async {
    await pumpScanner(tester);

    expect(find.textContaining('a até 100 m do terminal'), findsOneWidget);
    expect(find.textContaining('Nenhum acesso é liberado'), findsNothing);
  });

  testWidgets('QR lido envia o pedido e mostra "Acesso liberado"', (
    tester,
  ) async {
    await pumpScanner(tester);

    await scan(tester);

    expect(access.requests, hasLength(1));
    expect(find.text('Acesso liberado'), findsOneWidget);
    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.text('Concluir'), findsOneWidget);
    // A câmera e a barra do scanner saem: o resultado ocupa a tela.
    expect(find.text('Escanear QR'), findsNothing);
    expect(find.text('simular leitura'), findsNothing);
  });

  testWidgets('decisão negada mostra "Acesso negado" com o motivo', (
    tester,
  ) async {
    access.result = deniedResult(DenialReason.noUsesLeft);
    await pumpScanner(tester);

    await scan(tester);

    expect(find.text('Acesso negado'), findsOneWidget);
    expect(
      find.text('Sem usos restantes — procure a portaria'),
      findsOneWidget,
    );
    expect(find.text('Acesso liberado'), findsNothing);
  });

  testWidgets('Escanear de novo volta à câmera e usa outro requestId', (
    tester,
  ) async {
    access.result = deniedResult(DenialReason.outOfRange);
    await pumpScanner(tester);
    await scan(tester);

    await tester.tap(find.text('Escanear de novo'));
    await tester.pumpAndSettle();

    expect(instruction, findsOneWidget);
    expect(find.text('Acesso negado'), findsNothing);

    await scan(tester);
    expect(access.requests.map((r) => r.requestId), ['id-1', 'id-2']);
  });

  testWidgets('mostra "Verificando seu acesso…" enquanto o backend decide', (
    tester,
  ) async {
    final gate = access.gate = Completer<void>();
    await pumpScanner(tester);

    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Verificando seu acesso…'), findsOneWidget);
    // A câmera continua aberta, mas uma nova leitura não gera outro pedido.
    await tester.tap(find.text('simular leitura'));
    await tester.pump();
    expect(access.requests, hasLength(1));

    gate.complete();
    await tester.pumpAndSettle();
    expect(find.text('Acesso liberado'), findsOneWidget);
  });

  testWidgets('falha de rede oferece tentar novamente com o mesmo pedido', (
    tester,
  ) async {
    access.script.addAll([AccessFailureReason.network, grantedResult()]);
    await pumpScanner(tester);

    await scan(tester);

    expect(find.byType(FeedbackBanner), findsOneWidget);
    expect(find.textContaining('Sem conexão com o servidor'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsOneWidget);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Acesso liberado'), findsOneWidget);
    expect(access.requests.map((r) => r.requestId), ['id-1', 'id-1']);
  });

  testWidgets('pedido recusado só oferece escanear de novo', (tester) async {
    access.script.add(AccessFailureReason.invalidRequest);
    await pumpScanner(tester);

    await scan(tester);

    expect(find.textContaining('O servidor recusou a leitura'), findsOneWidget);
    expect(find.text('Tentar novamente'), findsNothing);
    expect(find.text('Escanear de novo'), findsOneWidget);

    await tester.tap(find.text('Escanear de novo'));
    await tester.pumpAndSettle();
    expect(instruction, findsOneWidget);
  });

  testWidgets('QR que não é de terminal avisa sem pedir a posição', (
    tester,
  ) async {
    scanner.scanValue = 'QR-1234';
    await pumpScanner(tester);

    await scan(tester);

    expect(find.textContaining('não é o QR de um terminal'), findsOneWidget);
    expect(location.positionReads, 0);
    expect(access.requests, isEmpty);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });

  testWidgets('o valor do QR nunca aparece na tela', (tester) async {
    access.script.addAll([AccessFailureReason.timeout, grantedResult()]);
    await pumpScanner(tester);

    await scan(tester);
    expect(find.textContaining('v1.terminal-01'), findsNothing);
    expect(find.textContaining('AbCd'), findsNothing);

    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    expect(find.textContaining('v1.terminal-01'), findsNothing);
  });

  testWidgets('explica a permissão negada e oferece nova tentativa', (
    tester,
  ) async {
    location.permission = ScannerPermission.denied;
    await pumpScanner(tester);

    expect(
      find.textContaining('Permissão de localização negada'),
      findsOneWidget,
    );
    expect(find.text('Permitir novamente'), findsOneWidget);

    location.permission = ScannerPermission.granted;
    await tester.tap(find.text('Permitir novamente'));
    await tester.pumpAndSettle();

    expect(instruction, findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
  });

  testWidgets('mostra erro de posição e permite tentar de novo', (
    tester,
  ) async {
    location.failure = LocationFailureReason.timeout;
    await pumpScanner(tester);

    await scan(tester);

    expect(
      find.textContaining('Não foi possível obter a posição'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);
    expect(access.requests, isEmpty);

    location.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await scan(tester);

    expect(find.text('Acesso liberado'), findsOneWidget);
  });

  testWidgets('a tela de leitura não estoura com fonte 2x em 360x640', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    access.script.add(AccessFailureReason.unavailable);
    await pumpScanner(tester);

    await tester.ensureVisible(find.text('simular leitura'));
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Tentar novamente'), findsOneWidget);
  });
}

class _SlowLocation implements LocationGateway {
  _SlowLocation(this.permission);

  final Completer<ScannerPermission> permission;

  @override
  Future<ScannerPermission> requestPermission() => permission.future;

  @override
  Future<GeoCoordinate> currentPosition() async =>
      const GeoCoordinate(latitude: 0, longitude: 0);
}
