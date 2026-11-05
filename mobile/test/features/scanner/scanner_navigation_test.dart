import 'package:controle_acesso/app.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/http_access_gateway.dart';
import 'package:controle_acesso/features/scanner/scanner_gateways.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeAccessGateway access;

  setUp(() => access = FakeAccessGateway());

  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...authOverrides(store: InMemorySessionStore(sessionFor())),
          locationGatewayProvider.overrideWithValue(FakeLocationGateway()),
          qrScannerGatewayProvider.overrideWithValue(FakeQrScannerGateway()),
          accessGatewayProvider.overrideWithValue(access),
        ],
        child: const App(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('usuário logado vai da Home ao scanner', (tester) async {
    await pumpApp(tester);

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Escanear QR'), findsOneWidget);
    expect(find.textContaining('US-29'), findsNothing);

    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('simular leitura'), findsOneWidget);
  });

  testWidgets('acesso liberado: Concluir volta à Home', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso liberado'), findsOneWidget);

    await tester.tap(find.text('Concluir'));
    await tester.pumpAndSettle();

    expect(find.text('Início'), findsOneWidget);
    expect(find.text('Acesso liberado'), findsNothing);
  });

  // O controller é global e guarda o último estado: o primeiro quadro do
  // scanner reaberto não pode mostrar a decisão da leitura anterior (um leitor
  // de tela chegou a poder anunciá-la). `pumpAndSettle` esconde o problema,
  // por isso olhamos só o primeiro quadro.
  for (final (nome, result, titulo) in [
    ('liberado', null, 'Acesso liberado'),
    ('negado', DenialReason.outOfRange, 'Acesso negado'),
  ]) {
    testWidgets('reabrir o scanner depois de "$nome" não mostra o resultado '
        'anterior no primeiro quadro', (tester) async {
      if (result != null) access.result = deniedResult(result);
      await pumpApp(tester);
      await tester.tap(find.text('Escanear QR'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('simular leitura'));
      await tester.pumpAndSettle();
      expect(find.text(titulo), findsOneWidget);
      await tester.tap(
        find.text(result == null ? 'Concluir' : 'Voltar ao início'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Início'), findsOneWidget);

      await tester.tap(find.text('Escanear QR'));
      await tester.pump();

      expect(find.text(titulo), findsNothing);
      expect(
        find.text('Solicitando permissão de localização…'),
        findsOneWidget,
      );

      await tester.pumpAndSettle();
      expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    });
  }

  testWidgets('acesso negado: volta ao início ou escaneia de novo', (
    tester,
  ) async {
    access.result = deniedResult(DenialReason.authorizationNotStarted);
    await pumpApp(tester);
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('simular leitura'));
    await tester.pumpAndSettle();
    expect(find.text('Acesso negado'), findsOneWidget);

    await tester.tap(find.text('Voltar ao início'));
    await tester.pumpAndSettle();
    expect(find.text('Início'), findsOneWidget);

    // Voltar ao scanner depois de um resultado recomeça do zero.
    await tester.tap(find.text('Escanear QR'));
    await tester.pumpAndSettle();
    expect(find.text('Aponte a câmera para o QR'), findsOneWidget);
    expect(find.text('Acesso negado'), findsNothing);
  });
}
