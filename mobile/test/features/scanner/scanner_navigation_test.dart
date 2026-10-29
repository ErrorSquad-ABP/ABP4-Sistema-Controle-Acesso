import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  testWidgets('usuário logado vai da Home ao scanner', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(store: InMemorySessionStore(sessionFor())),
          locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
          qrScannerGatewayProvider.overrideWithValue(FakeQrScannerGateway()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);

    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('simular leitura'), findsOneWidget);
  });
}
