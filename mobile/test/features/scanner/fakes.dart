import 'dart:async';

import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:flutter/material.dart';

class FakeQrScannerGateway implements QrScannerGateway {
  String scanValue = 'QR-1234';
  ValueChanged<String>? detect;
  ValueChanged<String>? fail;

  @override
  Widget preview({
    required ValueChanged<String> onDetected,
    required ValueChanged<String> onError,
  }) {
    detect = onDetected;
    fail = onError;
    return TextButton(
      onPressed: () => onDetected(scanValue),
      child: const Text('simular leitura'),
    );
  }
}

class FakeLocationGateway implements LocationGateway {
  ScannerPermission permission = ScannerPermission.granted;
  GeoCoordinate point = const GeoCoordinate(
    latitude: -23.55052,
    longitude: -46.633308,
  );
  LocationFailureReason? failure;
  Completer<GeoCoordinate>? pending;
  int permissionRequests = 0;
  int positionReads = 0;
  bool permissionFails = false;

  @override
  Future<ScannerPermission> requestPermission() async {
    permissionRequests++;
    if (permissionFails) throw Exception('plugin indisponivel');
    return permission;
  }

  @override
  Future<GeoCoordinate> currentPosition() {
    positionReads++;
    final pendingRead = pending;
    if (pendingRead != null) return pendingRead.future;
    final reason = failure;
    if (reason != null) {
      return Future<GeoCoordinate>.error(LocationFailure(reason));
    }
    return Future<GeoCoordinate>.value(point);
  }
}
