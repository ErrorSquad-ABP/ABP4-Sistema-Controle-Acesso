import 'dart:async';

import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/nfc_access/nfc_access_page.dart';
import 'package:controle_acesso/features/nfc_access/nfc_credential_gateway.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('sair durante a emissão não rearma o NFC', (tester) async {
    final gateway = _PendingGateway();
    final nativeCalls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('abp4/nfc'),
      (call) async {
        nativeCalls.add(call.method);
        return call.method == 'isSupported' ? true : null;
      },
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [nfcCredentialGatewayProvider.overrideWithValue(gateway)],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const NfcAccessPage(),
        ),
      ),
    );
    await tester.pump();
    expect(gateway.requested, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    gateway.response.complete(
      NfcCredential(
        token: '0123456789abcdef0123456789abcdef',
        expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 1)),
      ),
    );
    await tester.pump();

    expect(nativeCalls, ['isSupported', 'clearToken']);
  });
}

class _PendingGateway implements NfcCredentialGateway {
  final response = Completer<NfcCredential>();
  bool requested = false;

  @override
  Future<NfcCredential> issue() {
    requested = true;
    return response.future;
  }
}
