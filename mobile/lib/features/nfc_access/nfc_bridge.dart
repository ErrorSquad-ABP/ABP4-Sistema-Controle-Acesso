import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final nfcBridgeProvider = Provider<NfcBridge>((ref) => const NfcBridge());

/// Ponte com o HostApduService nativo: a prova fica só na memoria do processo.
class NfcBridge {
  const NfcBridge();

  static const MethodChannel _channel = MethodChannel('abp4/nfc');

  Future<bool> isSupported() async =>
      await _channel.invokeMethod<bool>('isSupported') ?? false;

  Future<void> setToken(String token) =>
      _channel.invokeMethod<void>('setToken', {'token': token});

  Future<void> clearToken() => _channel.invokeMethod<void>('clearToken');
}
