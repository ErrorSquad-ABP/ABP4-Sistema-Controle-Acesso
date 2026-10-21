import 'dart:async';

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
    return MobileScanner(
      onDetect: (capture) {
        for (final barcode in capture.barcodes) {
          final value = barcode.rawValue?.trim() ?? '';
          if (value.isNotEmpty) {
            onDetected(value);
            return;
          }
        }
      },
      errorBuilder: (context, error) {
        final message = _cameraMessage(error.errorCode);
        // errorBuilder roda durante o build; o controller nao pode mudar de
        // estado na mesma frame.
        WidgetsBinding.instance.addPostFrameCallback((_) => onError(message));
        return Center(
          child: Icon(
            Icons.videocam_off_outlined,
            size: AppSpacing.xl,
            color: context.palette.textSecondary,
          ),
        );
      },
    );
  }

  String _cameraMessage(MobileScannerErrorCode code) => switch (code) {
    MobileScannerErrorCode.permissionDenied =>
      'Permissão de câmera negada. Libere o acesso nas configurações do '
          'aparelho.',
    MobileScannerErrorCode.unsupported =>
      'Este dispositivo não suporta a leitura de QR.',
    _ => 'Não foi possível abrir a câmera. Tente novamente.',
  };
}

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
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      return GeoCoordinate(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } on TimeoutException {
      throw const LocationFailure(LocationFailureReason.timeout);
    } on PermissionDeniedException {
      throw const LocationFailure(LocationFailureReason.denied);
    } on LocationServiceDisabledException {
      throw const LocationFailure(LocationFailureReason.serviceDisabled);
    } on Exception {
      throw const LocationFailure(LocationFailureReason.unknown);
    }
  }
}
