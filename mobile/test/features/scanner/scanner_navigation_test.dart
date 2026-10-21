import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  testWidgets('modo demonstração abre a Home e leva ao scanner', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
          qrScannerGatewayProvider.overrideWithValue(FakeQrScannerGateway()),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('nenhuma sessão é criada'), findsOneWidget);

    await tester.ensureVisible(find.text('Entrar em modo demonstração'));
    await tester.tap(find.text('Entrar em modo demonstração'));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);

    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('simular leitura'), findsOneWidget);
  });
}
