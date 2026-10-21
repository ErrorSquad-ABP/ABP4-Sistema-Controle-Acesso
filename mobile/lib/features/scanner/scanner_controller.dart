import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final class ScannerLocating extends ScannerState {
  const ScannerLocating(this.qrValue);

  final String qrValue;
}

final class ScannerResult extends ScannerState {
  const ScannerResult({
    required this.qrValue,
    required this.latitude,
    required this.longitude,
  });

  final String qrValue;
  final double latitude;
  final double longitude;
}

final class ScannerFailure extends ScannerState {
  const ScannerFailure(this.message);

  final String message;
}

/// Fluxo do scanner: permissão de localização, leitura do QR e posição.
///
/// A US-10 só lê e exibe o resultado; liberar acesso é responsabilidade da
/// US-29, portanto nada aqui chama o backend.
final scannerControllerProvider =
    NotifierProvider<ScannerController, ScannerState>(ScannerController.new);

class ScannerController extends Notifier<ScannerState> {
  @override
  ScannerState build() => const ScannerRequestingPermission();

  Future<void> requestPermission() async {
    state = const ScannerRequestingPermission();
    final permission = await ref
        .read(locationGatewayProvider)
        .requestPermission();
    if (!ref.mounted) return;
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
  }

  /// Repete a etapa que falhou: pede a permissão de novo ou volta a escanear.
  Future<void> retry() async {
    if (state is ScannerPermissionDenied) return requestPermission();
    state = const ScannerScanning();
  }

  Future<void> onQrDetected(String value) async {
    final qrValue = value.trim();
    if (qrValue.isEmpty || state is! ScannerScanning) return;

    state = ScannerLocating(qrValue);
    try {
      final point = await ref.read(locationGatewayProvider).currentPosition();
      if (!ref.mounted) return;
      state = ScannerResult(
        qrValue: qrValue,
        latitude: point.latitude,
        longitude: point.longitude,
      );
    } on LocationFailure catch (failure) {
      if (!ref.mounted) return;
      state = ScannerFailure(_messageFor(failure.reason));
    } catch (_) {
      if (!ref.mounted) return;
      state = const ScannerFailure(ScannerMessages.positionUnavailable);
    }
  }

  void onCameraError(String message) {
    if (state is! ScannerScanning) return;
    state = ScannerFailure(message);
  }

  String _messageFor(LocationFailureReason reason) => switch (reason) {
    LocationFailureReason.serviceDisabled => ScannerMessages.serviceDisabled,
    LocationFailureReason.denied => ScannerMessages.positionDenied,
    LocationFailureReason.timeout => ScannerMessages.timeout,
    LocationFailureReason.unknown => ScannerMessages.positionUnavailable,
  };
}
