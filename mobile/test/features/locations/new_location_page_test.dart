import 'dart:async';

import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/locations/http_location_gateway.dart';
import 'package:controle_acesso/features/locations/location_contract.dart';
import 'package:controle_acesso/features/locations/new_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

/// Abre o formulário por push, como a tela de locais faz, para conferir que
/// o sucesso volta para a rota anterior.
class _Host extends StatelessWidget {
  const _Host();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder: (context) => const NewLocationPage(),
              ),
            ),
            child: const Text('abrir formulario'),
          ),
        ),
      ),
    );
  }
}

void main() {
  late FakeLocationGateway gateway;

  setUp(() {
    gateway = FakeLocationGateway();
  });

  Future<void> pumpForm(
    WidgetTester tester, {
    bool settle = true,
    Size size = const Size(390, 844),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentSessionProvider.overrideWithValue(sessionFor(user: adminUser)),
          locationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const _Host()),
      ),
    );
    await tester.tap(find.text('abrir formulario'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  Future<void> fill(
    WidgetTester tester, {
    String name = 'Portaria Norte',
    String description = '',
    String latitude = '0',
    String longitude = '0',
    String radius = '100',
  }) async {
    await tester.enterText(find.byKey(const Key('field-name')), name);
    await tester.enterText(
      find.byKey(const Key('field-description')),
      description,
    );
    await tester.enterText(find.byKey(const Key('field-latitude')), latitude);
    await tester.enterText(find.byKey(const Key('field-longitude')), longitude);
    await tester.enterText(find.byKey(const Key('field-radius')), radius);
  }

  testWidgets('mostra os campos do Figma e os campos do contrato', (
    tester,
  ) async {
    await pumpForm(tester);

    expect(find.text('Novo local'), findsOneWidget);
    expect(
      find.text(
        'Identifique o local e informe o endereço do ponto de acesso.',
      ),
      findsOneWidget,
    );
    expect(find.text('Nome do local'), findsOneWidget);
    expect(find.text('Endereço'), findsOneWidget);
    expect(find.text('Latitude'), findsOneWidget);
    expect(find.text('Longitude'), findsOneWidget);
    expect(find.text('Raio (metros)'), findsOneWidget);
    expect(find.text('Salvar local'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('save-location-action'))).height,
      greaterThanOrEqualTo(48),
    );
    expect(
      tester.getSize(find.byKey(const Key('back-to-locations'))).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('campos vazios não chamam a API e mostram os erros', (
    tester,
  ) async {
    await pumpForm(tester);

    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do local.'), findsOneWidget);
    expect(find.text('Informe a latitude.'), findsOneWidget);
    expect(find.text('Informe a longitude.'), findsOneWidget);
    expect(find.text('Informe o raio em metros.'), findsOneWidget);
    expect(gateway.created, isEmpty);
  });

  testWidgets('aceita os limites do contrato e envia a requisição', (
    tester,
  ) async {
    await pumpForm(tester);

    await fill(tester, name: 'Portaria', latitude: '90', longitude: '-180');
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    final request = gateway.created.single;
    expect(request.name, 'Portaria');
    expect(request.description, isEmpty);
    expect(request.latitude, 90);
    expect(request.longitude, -180);
    expect(request.radiusMeters, 100);
    expect(find.text('abrir formulario'), findsOneWidget);
  });

  testWidgets('recusa limites fora do contrato sem chamar a API', (
    tester,
  ) async {
    await pumpForm(tester);

    await fill(
      tester,
      name: 'A',
      latitude: '-90,1',
      longitude: '180,1',
      radius: '101',
    );
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('O nome deve ter pelo menos 2 caracteres.'),
      findsOneWidget,
    );
    expect(
      find.text('A latitude deve ficar entre -90 e 90.'),
      findsOneWidget,
    );
    expect(
      find.text('A longitude deve ficar entre -180 e 180.'),
      findsOneWidget,
    );
    expect(
      find.text('O raio deve ficar entre 1 e 100 metros.'),
      findsOneWidget,
    );
    expect(gateway.created, isEmpty);
  });

  testWidgets('raio zero é recusado pelo limite mínimo', (tester) async {
    await pumpForm(tester);

    await fill(tester, radius: '0');
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('O raio deve ficar entre 1 e 100 metros.'),
      findsOneWidget,
    );
    expect(gateway.created, isEmpty);
  });

  testWidgets('endereço acima de 200 caracteres é recusado', (tester) async {
    await pumpForm(tester);

    await fill(tester, description: 'A' * 201);
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('O endereço deve ter até 200 caracteres.'),
      findsOneWidget,
    );
    expect(gateway.created, isEmpty);
  });

  testWidgets('vírgula decimal vira número no corpo do contrato', (
    tester,
  ) async {
    await pumpForm(tester);

    await fill(tester, latitude: '-23,1857', longitude: '-45,8846');
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(gateway.created.single.latitude, -23.1857);
    expect(gateway.created.single.longitude, -45.8846);
  });

  for (final (reason, message) in [
    (
      LocationFailureReason.invalidRequest,
      'O servidor recusou os dados do local. Confira nome, endereço, '
          'coordenadas e raio.',
    ),
    (
      LocationFailureReason.forbidden,
      'Só administradores podem cadastrar locais.',
    ),
    (
      LocationFailureReason.unavailable,
      'O serviço de locais está fora do ar. Tente novamente em instantes.',
    ),
  ]) {
    testWidgets('${reason.name} mostra a mensagem própria e mantém a tela', (
      tester,
    ) async {
      gateway.createFailure = reason;
      await pumpForm(tester);

      await fill(tester);
      await tester.tap(find.byKey(const Key('save-location-action')));
      await tester.pumpAndSettle();

      expect(find.text(message), findsOneWidget);
      expect(find.byType(NewLocationPage), findsOneWidget);
      expect(gateway.created, hasLength(1));
    });
  }

  testWidgets('sem rede mostra o aviso e permite tentar de novo', (
    tester,
  ) async {
    gateway.createFailure = LocationFailureReason.network;
    await pumpForm(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Sem conexão com o servidor. Verifique sua internet e tente novamente.',
      ),
      findsOneWidget,
    );

    gateway.createFailure = null;
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(gateway.created, hasLength(2));
    expect(find.text('abrir formulario'), findsOneWidget);
  });

  testWidgets('salvando mostra o progresso e ignora toques repetidos', (
    tester,
  ) async {
    gateway.createGate = Completer<void>();
    await pumpForm(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pump();

    expect(find.text('Salvando…'), findsOneWidget);

    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pump();
    expect(gateway.created, hasLength(1));

    gateway.createGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('abrir formulario'), findsOneWidget);
  });

  testWidgets('erro fora do contrato não quebra o formulário', (tester) async {
    gateway.createCrash = StateError('boom');
    await pumpForm(tester);

    await fill(tester);
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(
      find.text('Não foi possível salvar o local. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('formulário não estoura com fonte 1.3x em 360x640', (
    tester,
  ) async {
    await pumpForm(
      tester,
      size: const Size(360, 640),
      textScale: 1.3,
    );

    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(find.text('Informe o nome do local.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
