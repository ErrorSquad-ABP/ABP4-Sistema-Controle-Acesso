import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/clock.dart';
import '../auth/session_controller.dart';
import 'scanner_contracts.dart';
import 'scanner_gateways.dart';

final scannerStartupLocationProvider = Provider<ScannerStartupLocation>((ref) {
  return ScannerStartupLocation(
    ref.watch(locationGatewayProvider),
    ref.watch(clockProvider),
  );
});

final scannerLocationOnLaunchProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(
    currentSessionProvider.select((session) => session?.user.id),
  );
  if (userId == null) return;

  final location = ref.watch(scannerStartupLocationProvider);
  final lifecycle = AppLifecycleListener(
    onResume: location.preload,
    onHide: location.clear,
  );
  ref.onDispose(() {
    lifecycle.dispose();
    location.clear();
  });
  final state = WidgetsBinding.instance.lifecycleState;
  if (state == null || state == AppLifecycleState.resumed) location.preload();
});

class ScannerStartupLocation {
  ScannerStartupLocation(this._gateway, this._now);

  static const _timeLimit = Duration(seconds: 10);
  static const _maxAge = Duration(seconds: 10);
  static const _maxAccuracyMeters = 25.0;

  final LocationGateway _gateway;
  final DateTime Function() _now;
  Future<GeoCoordinate?>? _startup;
  int _generation = 0;

  void preload() {
    _startup ??= _preloadIfAllowed(_generation);
  }

  void clear() {
    _generation++;
    _startup = null;
  }

  Future<GeoCoordinate?> _preloadIfAllowed(int generation) async {
    try {
      final permission = await Geolocator.checkPermission();
      if (generation != _generation ||
          (permission != LocationPermission.always &&
              permission != LocationPermission.whileInUse)) {
        return null;
      }
      return await _gateway.currentPosition();
    } on Exception {
      return null;
    }
  }

  Future<GeoCoordinate> positionForScan() async {
    final elapsed = Stopwatch()..start();
    try {
      final startup = _startup;
      if (startup != null) {
        final point = await startup.timeout(_timeLimit);
        if (identical(startup, _startup) && point != null && _canReuse(point)) {
          return point;
        }
      }

      final remaining = _timeLimit - elapsed.elapsed;
      if (remaining <= Duration.zero) {
        throw const LocationFailure(LocationFailureReason.timeout);
      }
      return await _gateway.currentPosition().timeout(remaining);
    } on TimeoutException {
      throw const LocationFailure(LocationFailureReason.timeout);
    }
  }

  bool _canReuse(GeoCoordinate point) {
    final measuredAt = point.measuredAt;
    final accuracy = point.accuracyMeters;
    if (measuredAt == null || accuracy == null) return false;
    final age = _now().difference(measuredAt);
    return !age.isNegative &&
        age <= _maxAge &&
        accuracy >= 0 &&
        accuracy <= _maxAccuracyMeters;
  }
}
