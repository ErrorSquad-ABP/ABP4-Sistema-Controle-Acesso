import 'package:flutter/widgets.dart';

/// Leitura de QR: a implementação real envolve o `mobile_scanner`, então a
/// página depende desta interface para poder ser testada sem a câmera.
abstract interface class QrScannerGateway {
  Widget preview({
    required ValueChanged<String> onDetected,
    required ValueChanged<String> onError,
  });
}

/// Posição do aparelho no momento da leitura.
abstract interface class LocationGateway {
  Future<ScannerPermission> requestPermission();

  Future<GeoCoordinate> currentPosition();
}

enum ScannerPermission { granted, denied, deniedForever, serviceDisabled }

enum LocationFailureReason { serviceDisabled, denied, timeout, unknown }

@immutable
class GeoCoordinate {
  const GeoCoordinate({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class LocationFailure implements Exception {
  const LocationFailure(this.reason);

  final LocationFailureReason reason;
}
