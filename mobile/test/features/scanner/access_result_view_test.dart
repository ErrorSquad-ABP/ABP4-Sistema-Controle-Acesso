import 'package:controle_acesso/core/clock.dart';
import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart';
import 'package:controle_acesso/features/scanner/access_messages.dart';
import 'package:controle_acesso/features/scanner/access_result_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  // Horários montados no fuso local: o teste vale em qualquer máquina.
  final now = DateTime(2026, 10, 27, 18);
  final entry = DateTime(2026, 10, 27, 14, 32).toUtc();
  var done = 0;
  var again = 0;

  setUp(() {
    done = 0;
    again = 0;
  });

  Future<void> pumpView(
    WidgetTester tester,
    AccessResult result, {
    ThemeData? theme,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWithValue(() => now)],
        child: MaterialApp(
          theme: theme ?? AppTheme.light(),
          home: Scaffold(
            body: AccessResultView(
              result: result,
              onDone: () => done++,
              onScanAgain: () => again++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('acesso liberado', () {
    testWidgets('mostra título, local, hora e o botão Concluir', (
      tester,
    ) async {
      await pumpView(tester, grantedResult(occurredAt: entry));

      expect(find.text('Acesso liberado'), findsOneWidget);
      expect(
        find.text('Tudo certo. Sua entrada foi autorizada.'),
        findsOneWidget,
      );
      expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
      expect(find.text('Entrada hoje'), findsOneWidget);
      expect(find.text('14:32'), findsOneWidget);
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.text('Concluir'), findsOneWidget);
      expect(find.text('Escanear de novo'), findsNothing);
    });

    testWidgets('Concluir chama o retorno ao início', (tester) async {
      await pumpView(tester, grantedResult(occurredAt: entry));

      await tester.tap(find.text('Concluir'));

      expect(done, 1);
      expect(again, 0);
    });

    testWidgets('sem local no evento esconde a linha do local', (tester) async {
      await pumpView(
        tester,
        grantedResult(locationName: null, occurredAt: entry),
      );

      expect(find.byIcon(Icons.apartment_outlined), findsNothing);
      expect(find.text('Entrada hoje'), findsOneWidget);
    });

    testWidgets('entrada de outro dia mostra a data, não "hoje"', (
      tester,
    ) async {
      await pumpView(
        tester,
        grantedResult(occurredAt: DateTime(2026, 10, 26, 23, 50).toUtc()),
      );

      expect(find.text('Entrada hoje'), findsNothing);
      expect(find.text('Entrada em 26/10/2026'), findsOneWidget);
      expect(find.text('23:50'), findsOneWidget);
    });

    testWidgets('anuncia o resultado para leitores de tela', (tester) async {
      await pumpView(tester, grantedResult(occurredAt: entry));

      expect(
        find.bySemanticsLabel(
          'Acesso liberado. Tudo certo. Sua entrada foi autorizada.',
        ),
        findsOneWidget,
      );
    });
  });

  group('acesso negado', () {
    testWidgets('mostra o motivo em linguagem simples e as duas saídas', (
      tester,
    ) async {
      await pumpView(tester, deniedResult(DenialReason.authorizationExpired));

      expect(find.text('Acesso negado'), findsOneWidget);
      expect(
        find.text('Autorização expirada — procure a portaria'),
        findsOneWidget,
      );
      expect(
        find.textContaining('A janela de acesso terminou'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(find.text('Escanear de novo'), findsOneWidget);
      expect(find.text('Voltar ao início'), findsOneWidget);
      expect(find.text('Concluir'), findsNothing);
    });

    testWidgets('os botões chamam o retorno certo', (tester) async {
      await pumpView(tester, deniedResult(DenialReason.outOfRange));

      await tester.tap(find.text('Escanear de novo'));
      await tester.tap(find.text('Voltar ao início'));

      expect(again, 1);
      expect(done, 1);
    });

    testWidgets('fora do alcance explica o limite de 100 m', (tester) async {
      await pumpView(tester, deniedResult(DenialReason.outOfRange));

      expect(find.text('Você está longe do terminal'), findsOneWidget);
      expect(find.textContaining('100 metros'), findsOneWidget);
    });

    testWidgets('QR expirado orienta a usar o QR atualizado', (tester) async {
      await pumpView(tester, deniedResult(DenialReason.credentialExpired));

      expect(find.text('QR expirado'), findsOneWidget);
      expect(find.textContaining('10 segundos'), findsOneWidget);
    });

    testWidgets('motivo desconhecido cai no texto genérico', (tester) async {
      await pumpView(tester, deniedResult(DenialReason.unknown));

      expect(find.text('Não foi possível liberar o acesso'), findsOneWidget);
    });

    for (final reason in DenialReason.values) {
      testWidgets('exibe o texto de ${reason.name} sem o código técnico', (
        tester,
      ) async {
        await pumpView(tester, deniedResult(reason));

        expect(find.text(reason.summary), findsOneWidget);
        expect(find.text(reason.guidance), findsOneWidget);
        if (reason.code.isNotEmpty) {
          expect(find.textContaining(reason.code), findsNothing);
        }
      });
    }
  });

  group('RNF04: fonte ampliada e tema escuro', () {
    void useSmallPhone(WidgetTester tester) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
    }

    for (final (nome, result) in [
      ('liberado', grantedResult(occurredAt: entry)),
      ('negado', deniedResult(DenialReason.noAuthorization)),
      ('negado com texto longo', deniedResult(DenialReason.credentialExpired)),
    ]) {
      testWidgets('$nome não estoura com fonte 2x em 360x640', (tester) async {
        useSmallPhone(tester);
        await pumpView(tester, result);

        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('com fonte 2x os botões continuam alcançáveis rolando', (
      tester,
    ) async {
      useSmallPhone(tester);
      await pumpView(tester, deniedResult(DenialReason.credentialExpired));

      await tester.scrollUntilVisible(
        find.text('Voltar ao início'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Voltar ao início'));

      expect(done, 1);
    });

    testWidgets('renderiza no tema escuro', (tester) async {
      await pumpView(
        tester,
        deniedResult(DenialReason.outOfRange),
        theme: AppTheme.dark(),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Acesso negado'), findsOneWidget);
    });
  });
}
