import 'dart:async';

import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/widgets/feedback_banner.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
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

  setUp(() {
    location = FakeLocationGateway();
    scanner = FakeQrScannerGateway();
  });

  Future<void> pumpScanner(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationGatewayProvider.overrideWithValue(location),
          qrScannerGatewayProvider.overrideWithValue(scanner),
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

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(scanner.detect, isNotNull);
  });

  testWidgets('mostra o QR e a posição após a leitura', (tester) async {
    await pumpScanner(tester);

    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();

    expect(find.byType(FeedbackBanner), findsOneWidget);
    expect(find.textContaining('QR-1234'), findsOneWidget);
    expect(find.textContaining('-23,550520'), findsOneWidget);
    expect(find.textContaining('-46,633308'), findsOneWidget);
    expect(find.text('Escanear outro'), findsOneWidget);
    expect(find.textContaining('Nenhum acesso é liberado'), findsOneWidget);
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

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.byType(FeedbackBanner), findsNothing);
  });

  testWidgets('mostra erro de posição e permite tentar de novo', (
    tester,
  ) async {
    location.failure = LocationFailureReason.timeout;
    await pumpScanner(tester);

    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Não foi possível obter a posição'),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    location.failure = null;
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();

    expect(find.textContaining('QR-1234'), findsOneWidget);
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
