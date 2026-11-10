import 'dart:async';

import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:controle_acesso/features/scanner/scanner_controller.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  late FakeLocationGateway location;
  late FakeQrScannerGateway scanner;
  late FakeAccessGateway access;
  late FakeRequestIds ids;
  late ProviderContainer container;
  late ProviderSubscription<ScannerState> subscription;

  ScannerController controller() =>
      container.read(scannerControllerProvider.notifier);
  ScannerState state() => container.read(scannerControllerProvider);

  Future<void> scanning() => controller().requestPermission();

  setUp(() {
    location = FakeLocationGateway();
    scanner = FakeQrScannerGateway();
    access = FakeAccessGateway();
    ids = FakeRequestIds();
    container = ProviderContainer(
      overrides: [
        locationGatewayProvider.overrideWithValue(location),
        qrScannerGatewayProvider.overrideWithValue(scanner),
        accessGatewayProvider.overrideWithValue(access),
        requestIdFactoryProvider.overrideWithValue(ids.call),
      ],
    );
    addTearDown(container.dispose);
    subscription = container.listen(scannerControllerProvider, (_, _) {});
    addTearDown(subscription.close);
  });

  group('permissão e câmera', () {
    test('ignora leitura tardia da câmera após descarte', () async {
      await scanning();
      final previous = controller();
      subscription.close();
      await container.pump();

      await expectLater(previous.onQrDetected(validQr), completes);

      expect(location.positionReads, 0);
      expect(access.requests, isEmpty);
    });

    test('ignora erro tardio da câmera após descarte', () async {
      await scanning();
      final previous = controller();
      subscription.close();
      await container.pump();

      expect(() => previous.onCameraError('Câmera fechada.'), returnsNormally);
    });

    test('começa pedindo a permissão de localização', () {
      expect(state(), isA<ScannerRequestingPermission>());
    });

    test('permissão concedida libera a leitura', () async {
      await scanning();

      expect(state(), isA<ScannerScanning>());
      expect(location.permissionRequests, 1);
    });

    test('permissão negada bloqueia a leitura e pode ser repetida', () async {
      location.permission = ScannerPermission.denied;
      await scanning();
      expect(state(), isA<ScannerPermissionDenied>());

      location.permission = ScannerPermission.granted;
      await controller().retry();

      expect(state(), isA<ScannerScanning>());
      expect(location.permissionRequests, 2);
    });

    test('permissão negada para sempre orienta as configurações', () async {
      location.permission = ScannerPermission.deniedForever;
      await scanning();

      final denied = state();
      expect(denied, isA<ScannerPermissionDenied>());
      expect((denied as ScannerPermissionDenied).permanent, isTrue);
      expect(denied.message, contains('configurações'));
    });

    test('falha ao pedir permissão vira erro recuperável', () async {
      location.permissionFails = true;
      await scanning();
      expect(state(), isA<ScannerFailure>());

      location.permissionFails = false;
      await controller().retry();
      expect(state(), isA<ScannerScanning>());
    });

    test('GPS desligado vira erro com opção de tentar novamente', () async {
      location.permission = ScannerPermission.serviceDisabled;
      await scanning();
      expect(state(), isA<ScannerFailure>());

      location.permission = ScannerPermission.granted;
      await controller().retry();
      expect(state(), isA<ScannerScanning>());
    });

    test('erro da câmera interrompe a leitura', () async {
      await scanning();

      controller().onCameraError('Câmera indisponível.');

      expect((state() as ScannerFailure).message, 'Câmera indisponível.');
    });
  });

  group('pedido de acesso (US-29)', () {
    test('QR válido envia terminal, posição, token e requestId', () async {
      await scanning();
      await controller().onQrDetected(validQr);

      final request = access.requests.single;
      expect(request.qrToken, validQr);
      expect(request.terminalId, 'terminal-01');
      expect(request.position.latitude, -23.55052);
      expect(request.position.longitude, -46.633308);
      expect(request.position.accuracyMeters, 12.5);
      expect(request.requestId, 'id-1');
      expect(location.positionReads, 1);
    });

    test('espaços ao redor do QR não vão para o backend', () async {
      await scanning();
      await controller().onQrDetected('  $validQr \n');

      expect(access.requests.single.qrToken, validQr);
    });

    test('decisão liberada vira o resultado liberado', () async {
      await scanning();
      await controller().onQrDetected(validQr);

      final result = state() as ScannerAccessResult;
      expect(result.granted, isTrue);
      expect(result.result.locationName, 'Edifício Aurora · Recepção');
    });

    test('decisão negada traz o motivo e não é erro', () async {
      access.result = deniedResult(DenialReason.authorizationExpired);
      await scanning();
      await controller().onQrDetected(validQr);

      final result = state() as ScannerAccessResult;
      expect(result.granted, isFalse);
      expect(result.result.reason, DenialReason.authorizationExpired);
    });

    test('mostra "enviando" enquanto espera a decisão', () async {
      final gate = access.gate = Completer<void>();
      await scanning();

      final sending = controller().onQrDetected(validQr);
      await pumpEventQueue();
      expect(state(), isA<ScannerSending>());

      gate.complete();
      await sending;
      expect(state(), isA<ScannerAccessResult>());
    });

    test('mostra "lendo posição" antes de enviar', () async {
      location.pending = Completer<GeoCoordinate>();
      await scanning();

      final reading = controller().onQrDetected(validQr);
      expect(state(), isA<ScannerLocating>());
      expect(access.requests, isEmpty);

      location.pending!.complete(location.point);
      await reading;
      expect(access.requests, hasLength(1));
    });
  });

  group('QR que não é de um terminal', () {
    for (final qr in [
      'QR-1234',
      'https://exemplo.com',
      'v2.terminal-01.1.11.sig',
      'v1.terminal-01.1.11',
      'v1.Terminal 01.1.11.sig',
    ]) {
      test('"$qr" não lê a posição nem chama a API', () async {
        await scanning();
        await controller().onQrDetected(qr);

        final failure = state() as ScannerFailure;
        expect(failure.message, ScannerMessages.invalidQr);
        expect(location.positionReads, 0);
        expect(access.requests, isEmpty);
        expect(ids.issued, 0);
      });
    }

    test('depois do aviso dá para escanear de novo', () async {
      await scanning();
      await controller().onQrDetected('QR-1234');
      await controller().retry();
      await controller().onQrDetected(validQr);

      expect(state(), isA<ScannerAccessResult>());
    });
  });

  group('uma leitura, um pedido', () {
    test('várias detecções do mesmo QR geram um único pedido', () async {
      final gate = access.gate = Completer<void>();
      location.pending = Completer<GeoCoordinate>();
      await scanning();

      final first = controller().onQrDetected(validQr);
      // O preview repete a detecção enquanto o QR está à vista.
      await controller().onQrDetected(validQr);
      await controller().onQrDetected(otherValidQr);
      location.pending!.complete(location.point);
      await pumpEventQueue();
      await controller().onQrDetected(validQr);
      gate.complete();
      await first;
      await controller().onQrDetected(validQr);

      expect(access.requests, hasLength(1));
      expect(location.positionReads, 1);
      expect(ids.issued, 1);
    });

    test('resultado não é sobrescrito por leituras tardias', () async {
      await scanning();
      await controller().onQrDetected(validQr);

      await controller().onQrDetected(otherValidQr);
      controller().onCameraError('Câmera indisponível.');

      expect(state(), isA<ScannerAccessResult>());
      expect(access.requests, hasLength(1));
    });

    test('"escanear de novo" gera outro requestId', () async {
      await scanning();
      await controller().onQrDetected(validQr);
      await controller().retry();
      expect(state(), isA<ScannerScanning>());

      await controller().onQrDetected(otherValidQr);

      expect(access.requests.map((r) => r.requestId), ['id-1', 'id-2']);
      expect(access.requests.last.terminalId, 'terminal-02');
    });
  });

  group('falhas no envio', () {
    test('erro de GPS mostra falha e permite escanear de novo', () async {
      await scanning();
      location.failure = LocationFailureReason.timeout;

      await controller().onQrDetected(validQr);
      final failure = state();
      expect(failure, isA<ScannerFailure>());
      expect((failure as ScannerFailure).message, contains('posição'));
      expect(access.requests, isEmpty);

      await controller().retry();
      expect(state(), isA<ScannerScanning>());

      location.failure = null;
      await controller().onQrDetected(otherValidQr);
      expect(state(), isA<ScannerAccessResult>());
    });

    test('rede fora permite reenviar com o MESMO requestId', () async {
      access.script.addAll([AccessFailureReason.network, grantedResult()]);
      await scanning();
      await controller().onQrDetected(validQr);

      final failed = state() as ScannerSendFailed;
      expect(failed.retryable, isTrue);
      expect(failed.message, ScannerMessages.accessNetwork);

      await controller().retrySend();

      expect(state(), isA<ScannerAccessResult>());
      expect(access.requests, hasLength(2));
      expect(access.requests.map((r) => r.requestId), ['id-1', 'id-1']);
      // A posição e o token também são os mesmos: é o mesmo pedido.
      expect(access.requests.last.qrToken, validQr);
      expect(location.positionReads, 1);
      expect(ids.issued, 1);
    });

    test('depois de reenviar com sucesso, o próximo QR usa outro id', () async {
      access.script.addAll([AccessFailureReason.timeout, grantedResult()]);
      await scanning();
      await controller().onQrDetected(validQr);
      await controller().retrySend();
      await controller().retry();

      await controller().onQrDetected(otherValidQr);

      expect(access.requests.last.requestId, 'id-2');
    });

    test('pode reenviar várias vezes antes de conseguir', () async {
      access.script.addAll([
        AccessFailureReason.unavailable,
        AccessFailureReason.tooManyRequests,
        grantedResult(),
      ]);
      await scanning();
      await controller().onQrDetected(validQr);
      await controller().retrySend();
      expect(state(), isA<ScannerSendFailed>());
      await controller().retrySend();

      expect(state(), isA<ScannerAccessResult>());
      expect(access.requests.map((r) => r.requestId).toSet(), {'id-1'});
    });

    for (final (reason, message, retryable) in [
      (
        AccessFailureReason.tooManyRequests,
        ScannerMessages.accessTooManyRequests,
        true,
      ),
      (
        AccessFailureReason.unavailable,
        ScannerMessages.accessUnavailable,
        true,
      ),
      (AccessFailureReason.network, ScannerMessages.accessNetwork, true),
      (AccessFailureReason.timeout, ScannerMessages.accessTimeout, true),
      (AccessFailureReason.unexpected, ScannerMessages.accessUnexpected, true),
      (
        AccessFailureReason.invalidRequest,
        ScannerMessages.accessInvalidRequest,
        false,
      ),
      (
        AccessFailureReason.unauthorized,
        ScannerMessages.accessUnauthorized,
        false,
      ),
    ]) {
      test('${reason.name}: mensagem própria e retryable=$retryable', () async {
        access.script.add(reason);
        await scanning();
        await controller().onQrDetected(validQr);

        final failed = state() as ScannerSendFailed;
        expect(failed.message, message);
        expect(failed.retryable, retryable);
      });
    }

    test('pedido recusado (400) não é reenviado: volta a escanear', () async {
      access.script.add(AccessFailureReason.invalidRequest);
      await scanning();
      await controller().onQrDetected(validQr);

      await controller().retrySend();

      expect(state(), isA<ScannerScanning>());
      expect(access.requests, hasLength(1));
    });

    test('erro fora do contrato no gateway vira falha reenviável', () async {
      access.crash = StateError('bug no gateway');
      await scanning();
      await controller().onQrDetected(validQr);

      final failed = state() as ScannerSendFailed;
      expect(failed.message, ScannerMessages.accessUnexpected);
      expect(failed.retryable, isTrue);
    });

    test('resposta de um envio abandonado não sobrescreve a tela', () async {
      final gate = access.gate = Completer<void>();
      await scanning();
      final sending = controller().onQrDetected(validQr);
      await pumpEventQueue();
      expect(state(), isA<ScannerSending>());

      // O usuário saiu e voltou: a tela pede a permissão de novo.
      await controller().requestPermission();
      expect(state(), isA<ScannerScanning>());
      gate.complete();
      await sending;

      expect(state(), isA<ScannerScanning>());
    });

    test(
      'retrySend fora de uma falha de envio apenas volta a escanear',
      () async {
        await scanning();

        await controller().retrySend();

        expect(state(), isA<ScannerScanning>());
        expect(access.requests, isEmpty);
      },
    );
  });

  group('newRequestId', () {
    test('gera UUID v4 válido e diferente a cada chamada', () {
      final uuid = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      );
      final seen = <String>{};
      for (var i = 0; i < 200; i++) {
        final id = newRequestId();
        expect(id, matches(uuid));
        seen.add(id);
      }
      expect(seen, hasLength(200));
    });
  });
}
