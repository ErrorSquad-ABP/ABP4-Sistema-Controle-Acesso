import 'dart:async';

import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:controle_acesso/features/scanner/scanner_controller.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeLocationGateway location;
  late FakeQrScannerGateway scanner;
  late ProviderContainer container;

  ScannerController controller() =>
      container.read(scannerControllerProvider.notifier);
  ScannerState state() => container.read(scannerControllerProvider);

  setUp(() {
    location = FakeLocationGateway();
    scanner = FakeQrScannerGateway();
    container = ProviderContainer(
      overrides: [
        locationGatewayProvider.overrideWithValue(location),
        qrScannerGatewayProvider.overrideWithValue(scanner),
      ],
    );
    addTearDown(container.dispose);
  });

  test('começa pedindo a permissão de localização', () {
    expect(state(), isA<ScannerRequestingPermission>());
  });

  test('permissão concedida libera a leitura', () async {
    await controller().requestPermission();

    expect(state(), isA<ScannerScanning>());
    expect(location.permissionRequests, 1);
  });

  test('permissão negada bloqueia a leitura e pode ser repetida', () async {
    location.permission = ScannerPermission.denied;
    await controller().requestPermission();
    expect(state(), isA<ScannerPermissionDenied>());

    location.permission = ScannerPermission.granted;
    await controller().retry();

    expect(state(), isA<ScannerScanning>());
    expect(location.permissionRequests, 2);
  });

  test('permissão negada para sempre orienta as configurações', () async {
    location.permission = ScannerPermission.deniedForever;
    await controller().requestPermission();

    final denied = state();
    expect(denied, isA<ScannerPermissionDenied>());
    expect((denied as ScannerPermissionDenied).permanent, isTrue);
    expect(denied.message, contains('configurações'));
  });

  test('GPS desligado vira erro com opção de tentar novamente', () async {
    location.permission = ScannerPermission.serviceDisabled;
    await controller().requestPermission();
    expect(state(), isA<ScannerFailure>());

    location.permission = ScannerPermission.granted;
    await controller().retry();
    expect(state(), isA<ScannerScanning>());
  });

  test('QR lido registra o valor e a posição', () async {
    await controller().requestPermission();
    await controller().onQrDetected('QR-1234');

    final result = state();
    expect(result, isA<ScannerResult>());
    result as ScannerResult;
    expect(result.qrValue, 'QR-1234');
    expect(result.latitude, -23.55052);
    expect(result.longitude, -46.633308);
    expect(location.positionReads, 1);
  });

  test('lê a posição uma única vez por QR', () async {
    await controller().requestPermission();
    final pending = Completer<GeoCoordinate>();
    location.pending = pending;

    final reading = controller().onQrDetected('QR-1234');
    expect(state(), isA<ScannerLocating>());
    await controller().onQrDetected('QR-9999');

    pending.complete(location.point);
    await reading;

    expect(location.positionReads, 1);
    expect((state() as ScannerResult).qrValue, 'QR-1234');
  });

  test('erro de GPS mostra falha e permite escanear de novo', () async {
    await controller().requestPermission();
    location.failure = LocationFailureReason.timeout;

    await controller().onQrDetected('QR-1234');
    final failure = state();
    expect(failure, isA<ScannerFailure>());
    expect((failure as ScannerFailure).message, contains('posição'));

    await controller().retry();
    expect(state(), isA<ScannerScanning>());

    location.failure = null;
    await controller().onQrDetected('QR-4321');
    expect((state() as ScannerResult).qrValue, 'QR-4321');
  });

  test('erro da câmera interrompe a leitura', () async {
    await controller().requestPermission();

    controller().onCameraError('Câmera indisponível.');

    final failure = state() as ScannerFailure;
    expect(failure.message, 'Câmera indisponível.');
  });

  test('resultado não é sobrescrito por leituras tardias', () async {
    await controller().requestPermission();
    await controller().onQrDetected('QR-1234');

    await controller().onQrDetected('QR-0000');
    controller().onCameraError('Câmera indisponível.');

    expect((state() as ScannerResult).qrValue, 'QR-1234');
    expect(location.positionReads, 1);
  });
}
