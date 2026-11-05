import 'dart:async';

import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/scanner_contracts.dart';
import 'package:flutter/material.dart';

/// QR no formato do terminal: `v1.<terminalId>.<iat>.<exp>.<assinatura>`.
const validQr = 'v1.terminal-01.1790000000.1790000010.AbCd-_09';
const otherValidQr = 'v1.terminal-02.1790000010.1790000020.ZyXw-_90';

class FakeQrScannerGateway implements QrScannerGateway {
  String scanValue = validQr;
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
    accuracyMeters: 12.5,
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

AccessResult grantedResult({
  String? locationName = 'Edifício Aurora · Recepção',
  DateTime? occurredAt,
}) => AccessResult(
  decision: AccessDecision.granted,
  reason: null,
  occurredAt: occurredAt ?? DateTime.utc(2026, 10, 27, 17, 32),
  locationName: locationName,
);

AccessResult deniedResult(DenialReason reason) => AccessResult(
  decision: AccessDecision.denied,
  reason: reason,
  occurredAt: DateTime.utc(2026, 10, 27, 17, 32),
  locationName: 'Edifício Aurora · Recepção',
);

/// Decide o pedido de acesso sem rede. `script` é consumido em ordem: um
/// [AccessResult] responde, uma [AccessFailureReason] falha; sem script, vale
/// [result].
class FakeAccessGateway implements AccessGateway {
  AccessResult result = grantedResult();
  final List<Object> script = [];

  /// Quando definido, o pedido só responde ao completar este completer.
  Completer<void>? gate;

  /// Lançado no lugar da resposta, para simular erro fora do contrato.
  Object? crash;

  final List<QrAccessRequest> requests = [];

  @override
  Future<AccessResult> requestQrAccess(QrAccessRequest request) async {
    requests.add(request);
    await gate?.future;
    final error = crash;
    if (error != null) throw error;
    if (script.isNotEmpty) {
      final next = script.removeAt(0);
      if (next is AccessFailureReason) throw AccessFailure(next);
      return next as AccessResult;
    }
    return result;
  }
}

/// Ids previsíveis: `id-1`, `id-2`…
class FakeRequestIds {
  int issued = 0;

  String call() => 'id-${++issued}';
}
