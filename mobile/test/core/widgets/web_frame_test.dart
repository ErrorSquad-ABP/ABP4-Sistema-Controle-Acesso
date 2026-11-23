import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/core/widgets/web_frame.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const probe = Key('conteudo');

  Future<double> pumpAndMeasure(
    WidgetTester tester, {
    required bool isWeb,
    required Size surface,
  }) async {
    // A view muda a área de desenho e o MediaQuery juntos (setSurfaceSize não).
    tester.view
      ..physicalSize = surface
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late double mediaWidth;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => WebFrame(isWeb: isWeb, child: child!),
        home: Builder(
          builder: (context) {
            mediaWidth = MediaQuery.sizeOf(context).width;
            return const Scaffold(body: SizedBox.expand(key: probe));
          },
        ),
      ),
    );
    expect(tester.getSize(find.byKey(probe)).width, mediaWidth);
    return mediaWidth;
  }

  testWidgets(
    'no navegador largo, conteúdo centralizado com largura de celular',
    (tester) async {
      final width = await pumpAndMeasure(
        tester,
        isWeb: true,
        surface: const Size(1280, 800),
      );

      expect(width, WebFrame.maxWidth);
      expect(tester.getCenter(find.byKey(probe)).dx, 640);
    },
  );

  testWidgets('no navegador estreito, ocupa a largura toda', (tester) async {
    final width = await pumpAndMeasure(
      tester,
      isWeb: true,
      surface: const Size(390, 800),
    );

    expect(width, 390);
  });

  testWidgets('fora do navegador não altera a tela', (tester) async {
    final width = await pumpAndMeasure(
      tester,
      isWeb: false,
      surface: const Size(1280, 800),
    );

    expect(width, 1280);
  });
}
