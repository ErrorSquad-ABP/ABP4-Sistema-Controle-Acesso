import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'access_contract.dart';
import 'http_access_gateway.dart';
import 'scanner_contracts.dart';
import 'scanner_gateways.dart';

abstract final class ScannerMessages {
  static const permissionDenied =
      'Permissão de localização negada. Autorize o acesso para registrar a '
      'posição da leitura.';
  static const permissionDeniedForever =
      'Permissão de localização negada definitivamente. Libere o acesso nas '
      'configurações do aparelho e tente novamente.';
  static const serviceDisabled =
      'Serviço de localização desligado. Ative o GPS do aparelho e tente '
      'novamente.';
  static const timeout =
      'Não foi possível obter a posição a tempo. Tente novamente.';
  static const positionDenied =
      'A permissão de localização foi revogada. Autorize novamente para '
      'continuar.';
  static const positionUnavailable =
      'Não foi possível ler a posição do aparelho. Tente novamente.';
  static const permissionUnavailable =
      'Não foi possível verificar a permissão de localização. Tente novamente.';
  static const invalidQr =
      'Este não é o QR de um terminal. Aponte a câmera para o QR exibido no '
      'terminal.';

  static const accessUnauthorized =
      'Sua sessão expirou. Entre novamente para continuar.';
  static const accessInvalidRequest =
      'O servidor recusou a leitura. Escaneie o QR do terminal novamente.';
  static const accessTooManyRequests =
      'Muitas tentativas em pouco tempo. Aguarde um instante e tente de novo.';
  static const accessUnavailable =
      'O serviço está indisponível no momento. Tente novamente em instantes.';
  static const accessNetwork =
      'Sem conexão com o servidor. Verifique sua internet e tente novamente.';
  static const accessTimeout =
      'O servidor demorou a responder. Tente novamente.';
  static const accessUnexpected =
      'Não foi possível verificar o acesso. Tente novamente.';
}

sealed class ScannerState {
  const ScannerState();
}

final class ScannerRequestingPermission extends ScannerState {
  const ScannerRequestingPermission();
}

final class ScannerScanning extends ScannerState {
  const ScannerScanning();
}

final class ScannerPermissionDenied extends ScannerState {
  const ScannerPermissionDenied({this.permanent = false});

  final bool permanent;

  String get message => permanent
      ? ScannerMessages.permissionDeniedForever
      : ScannerMessages.permissionDenied;
}

/// QR lido: obtendo a posição do aparelho. O valor do QR não fica no estado:
/// é uma credencial de 25 s e não aparece em nenhuma tela.
final class ScannerLocating extends ScannerState {
  const ScannerLocating();
}

/// Pedido enviado ao backend, aguardando a decisão.
final class ScannerSending extends ScannerState {
  const ScannerSending();
}

/// Decisão do backend: liberado ou negado (não é erro HTTP).
final class ScannerAccessResult extends ScannerState {
  const ScannerAccessResult(this.result);

  final AccessResult result;

  bool get granted => result.decision == AccessDecision.granted;
}

/// Falha antes do envio: câmera, permissão, posição ou QR que não é de terminal.
final class ScannerFailure extends ScannerState {
  const ScannerFailure(this.message);

  final String message;
}

/// Falha no envio. [retryable] diz se vale repetir o mesmo pedido (rede,
/// timeout, 429, 5xx) ou se é preciso escanear de novo.
final class ScannerSendFailed extends ScannerState {
  const ScannerSendFailed(this.message, {required this.retryable});

  final String message;
  final bool retryable;
}

/// Gera a chave de idempotência (UUID v4) de cada tentativa de acesso.
typedef RequestIdFactory = String Function();

String newRequestId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // versão 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variante RFC 4122
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

final requestIdFactoryProvider = Provider<RequestIdFactory>(
  (ref) => newRequestId,
);

/// Fluxo do scanner: permissão de localização, leitura do QR, posição e o
/// pedido de acesso ao backend (US-29).
final scannerControllerProvider =
    NotifierProvider.autoDispose<ScannerController, ScannerState>(
      ScannerController.new,
    );

class ScannerController extends Notifier<ScannerState> {
  int _operation = 0;

  /// Pedido em andamento. Repetir o envio depois de uma falha reaproveita o
  /// mesmo `requestId`, para o backend não consumir a autorização duas vezes.
  QrAccessRequest? _pending;

  @override
  ScannerState build() => const ScannerRequestingPermission();

  Future<void> requestPermission() async {
    final operation = ++_operation;
    _pending = null;
    state = const ScannerRequestingPermission();
    try {
      final permission = await ref
          .read(locationGatewayProvider)
          .requestPermission();
      if (!ref.mounted || operation != _operation) return;
      state = switch (permission) {
        ScannerPermission.granted => const ScannerScanning(),
        ScannerPermission.denied => const ScannerPermissionDenied(),
        ScannerPermission.deniedForever => const ScannerPermissionDenied(
          permanent: true,
        ),
        ScannerPermission.serviceDisabled => const ScannerFailure(
          ScannerMessages.serviceDisabled,
        ),
      };
    } catch (_) {
      if (!ref.mounted || operation != _operation) return;
      state = const ScannerFailure(ScannerMessages.permissionUnavailable);
    }
  }

  /// Repete a etapa que falhou: pede a permissão de novo ou volta a escanear.
  /// Também serve para "Escanear de novo" depois de um resultado.
  Future<void> retry() async {
    if (state is ScannerPermissionDenied) return requestPermission();
    ++_operation;
    _pending = null;
    state = const ScannerScanning();
  }

  /// Reenvia o mesmo pedido (mesmo `requestId`) depois de uma falha de envio.
  Future<void> retrySend() async {
    if (state is! ScannerSendFailed || _pending == null) return retry();
    await _send(++_operation);
  }

  Future<void> onQrDetected(String value) async {
    final qrValue = value.trim();
    // O preview repete a detecção enquanto o QR está à vista: só a primeira
    // leitura em `Scanning` vira pedido.
    if (!ref.mounted || qrValue.isEmpty || state is! ScannerScanning) return;

    final terminalId = terminalIdFromQrToken(qrValue);
    if (terminalId == null) {
      state = const ScannerFailure(ScannerMessages.invalidQr);
      return;
    }

    final operation = _operation;
    state = const ScannerLocating();
    final GeoCoordinate point;
    try {
      point = await ref.read(locationGatewayProvider).currentPosition();
    } on LocationFailure catch (failure) {
      if (!ref.mounted || operation != _operation) return;
      state = ScannerFailure(_messageFor(failure.reason));
      return;
    } catch (_) {
      if (!ref.mounted || operation != _operation) return;
      state = const ScannerFailure(ScannerMessages.positionUnavailable);
      return;
    }
    if (!ref.mounted || operation != _operation) return;

    _pending = QrAccessRequest(
      qrToken: qrValue,
      terminalId: terminalId,
      position: point,
      requestId: ref.read(requestIdFactoryProvider)(),
    );
    await _send(operation);
  }

  Future<void> _send(int operation) async {
    final request = _pending;
    if (request == null) return;
    state = const ScannerSending();
    try {
      final result = await ref
          .read(accessGatewayProvider)
          .requestQrAccess(request);
      if (!ref.mounted || operation != _operation) return;
      // Pedido concluído: a próxima leitura gera outro `requestId`.
      _pending = null;
      state = ScannerAccessResult(result);
    } on AccessFailure catch (failure) {
      if (!ref.mounted || operation != _operation) return;
      final retryable = _isRetryable(failure.reason);
      if (!retryable) _pending = null;
      state = ScannerSendFailed(
        _messageForAccess(failure.reason),
        retryable: retryable,
      );
    } catch (_) {
      if (!ref.mounted || operation != _operation) return;
      state = const ScannerSendFailed(
        ScannerMessages.accessUnexpected,
        retryable: true,
      );
    }
  }

  void onCameraError(String message) {
    if (!ref.mounted || state is! ScannerScanning) return;
    state = ScannerFailure(message);
  }

  String _messageFor(LocationFailureReason reason) => switch (reason) {
    LocationFailureReason.serviceDisabled => ScannerMessages.serviceDisabled,
    LocationFailureReason.denied => ScannerMessages.positionDenied,
    LocationFailureReason.timeout => ScannerMessages.timeout,
    LocationFailureReason.unknown => ScannerMessages.positionUnavailable,
  };

  /// Sessão recusada e pedido recusado não melhoram repetindo o mesmo envio.
  bool _isRetryable(AccessFailureReason reason) =>
      reason != AccessFailureReason.unauthorized &&
      reason != AccessFailureReason.invalidRequest;

  String _messageForAccess(AccessFailureReason reason) => switch (reason) {
    AccessFailureReason.unauthorized => ScannerMessages.accessUnauthorized,
    AccessFailureReason.invalidRequest => ScannerMessages.accessInvalidRequest,
    AccessFailureReason.tooManyRequests =>
      ScannerMessages.accessTooManyRequests,
    AccessFailureReason.unavailable => ScannerMessages.accessUnavailable,
    AccessFailureReason.network => ScannerMessages.accessNetwork,
    AccessFailureReason.timeout => ScannerMessages.accessTimeout,
    AccessFailureReason.unexpected => ScannerMessages.accessUnexpected,
  };
}
