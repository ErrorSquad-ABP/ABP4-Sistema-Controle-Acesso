import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_spacing.dart';
import 'scanner_contracts.dart';

final qrScannerGatewayProvider = Provider<QrScannerGateway>(
  (ref) => const MobileScannerGateway(),
);

final locationGatewayProvider = Provider<LocationGateway>(
  (ref) => const GeolocatorLocationGateway(),
);

class MobileScannerGateway implements QrScannerGateway {
  const MobileScannerGateway();

  @override
  Widget preview({
    required ValueChanged<String> onDetected,
    required ValueChanged<String> onError,
  }) {
    return _ScannerPreview(onDetected: onDetected, onError: onError);
  }
}

/// O display emite luz e o QR e pequeno no OLED: um zoom inicial util e o slider
/// manual resolvem sem o autoZoom do ML Kit reajustar a camera sozinho.
class _ScannerPreview extends StatefulWidget {
  const _ScannerPreview({required this.onDetected, required this.onError});

  final ValueChanged<String> onDetected;
  final ValueChanged<String> onError;

  @override
  State<_ScannerPreview> createState() => _ScannerPreviewState();
}

class _ScannerPreviewState extends State<_ScannerPreview> {
  final MobileScannerController _controller = MobileScannerController(
    autoZoom: false,
  );
  static const double _initialZoom = 0.35;
  double _zoom = _initialZoom;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_controller.setZoomScale(_initialZoom));
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(
          controller: _controller,
          onDetect: (capture) {
            for (final barcode in capture.barcodes) {
              final value = barcode.rawValue?.trim() ?? '';
              if (value.isNotEmpty) {
                widget.onDetected(value);
                return;
              }
            }
          },
          errorBuilder: (context, error) {
            final message = _cameraMessage(error.errorCode);
            // errorBuilder roda durante o build; o controller nao pode mudar de
            // estado na mesma frame.
            WidgetsBinding.instance.addPostFrameCallback((_) => widget.onError(message));
            return Center(
              child: Icon(
                Icons.videocam_off_outlined,
                size: AppSpacing.xl,
                color: context.palette.textSecondary,
              ),
            );
          },
        ),
        if (!kIsWeb)
          Positioned(
            left: 12,
            right: 12,
            bottom: 4,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 12),
                    child: Icon(Icons.zoom_out, size: 18, color: Colors.white),
                  ),
                  Expanded(
                    child: Slider(
                      value: _zoom,
                      label: 'Zoom',
                      activeColor: Colors.white,
                      inactiveColor: Colors.white30,
                      onChanged: (value) {
                        setState(() => _zoom = value);
                        unawaited(_controller.setZoomScale(value));
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Icon(Icons.zoom_in, size: 18, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _cameraMessage(MobileScannerErrorCode code) => switch (code) {
  MobileScannerErrorCode.permissionDenied =>
    'Permissão de câmera negada. Libere o acesso nas configurações do '
        'aparelho.',
  MobileScannerErrorCode.unsupported =>
    'Este dispositivo não suporta a leitura de QR.',
  _ => 'Não foi possível abrir a câmera. Tente novamente.',
};

class GeolocatorLocationGateway implements LocationGateway {
  const GeolocatorLocationGateway();

  @override
  Future<ScannerPermission> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return ScannerPermission.serviceDisabled;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse => ScannerPermission.granted,
      LocationPermission.deniedForever => ScannerPermission.deniedForever,
      _ => ScannerPermission.denied,
    };
  }

  @override
  Future<GeoCoordinate> currentPosition() async {
    // Prédios com estrutura metálica geram multipath: exigir GPS de alta
    // precisão pode nao fechar dentro do prazo. A precisao media usa Wi-Fi/
    // celular e entrega uma posicao utilizavel para a geofence.
    Position? lastKnown;
    try {
      lastKnown = await Geolocator.getLastKnownPosition();
    } on Exception {
      lastKnown = null;
    }
    if (lastKnown != null && _isFresh(lastKnown, const Duration(minutes: 2))) {
      return _toCoordinate(lastKnown);
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return _toCoordinate(position);
    } on TimeoutException {
      if (lastKnown != null && _isFresh(lastKnown, const Duration(minutes: 15))) {
        return _toCoordinate(lastKnown);
      }
      throw const LocationFailure(LocationFailureReason.timeout);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationFailureReason.denied);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    } on Exception {
      throw const LocationFailure(LocationFailureReason.unknown);
    }
  }

  bool _isFresh(Position position, Duration limit) {
    final age = DateTime.now().difference(position.timestamp);
    return !age.isNegative && age <= limit;
  }

  GeoCoordinate _toCoordinate(Position position) {
    // O contrato aceita so precisao finita e nao negativa.
    final accuracy = position.accuracy;
    return GeoCoordinate(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: accuracy.isFinite && accuracy >= 0 ? accuracy : null,
      measuredAt: position.timestamp,
    );
  }
}
