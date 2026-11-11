import 'dart:async';

import 'package:controle_acesso/core/theme/app_theme.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/auth/session_controller.dart';
import 'package:controle_acesso/features/locations/http_location_gateway.dart';
import 'package:controle_acesso/features/locations/location_contract.dart';
import 'package:controle_acesso/features/locations/locations_page.dart';
import 'package:controle_acesso/features/locations/new_location_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../auth/fakes.dart';
import 'fakes.dart';

void main() {
  late FakeLocationGateway gateway;

  setUp(() {
    gateway = FakeLocationGateway();
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    UserRole role = UserRole.admin,
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
          currentSessionProvider.overrideWithValue(
            sessionFor(user: role == UserRole.admin ? adminUser : maria),
          ),
          locationGatewayProvider.overrideWithValue(gateway),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const LocationsPage()),
      ),
    );
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
  }

  testWidgets('abre com o cabeçalho do Figma e a ação de cadastrar', (
    tester,
  ) async {
    await pumpPage(tester);

    expect(find.text('ADMINISTRAÇÃO'), findsOneWidget);
    expect(find.text('Locais de acesso'), findsOneWidget);
    expect(find.text('Novo local'), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('new-location-action'))).height,
        greaterThanOrEqualTo(48));
  });

  testWidgets('mostra o carregando e depois o vazio', (tester) async {
    gateway.listGate = Completer<void>();
    await pumpPage(tester, settle: false);

    expect(find.text('Carregando os locais…'), findsOneWidget);

    gateway.listGate!.complete();
    await tester.pumpAndSettle();

    expect(find.text('Nenhum local cadastrado'), findsOneWidget);
    expect(
      find.text('Os locais ativos do condomínio aparecerão aqui.'),
      findsOneWidget,
    );
  });

  testWidgets('lista nome, endereço, raio e coordenadas', (tester) async {
    gateway.page = pageOf([location()]);
    await pumpPage(tester);

    expect(find.text('Edifício Aurora · Recepção'), findsOneWidget);
    expect(find.text('Av. Central, 1200 · raio de 100 m'), findsOneWidget);
    expect(
      find.text('Latitude -23,1857 · Longitude -45,8846'),
      findsOneWidget,
    );
    expect(find.text('Ativo'), findsOneWidget);
    expect(gateway.lastPage, 1);
    expect(gateway.lastPageSize, 100);
  });

  testWidgets('local sem descrição mostra só o raio', (tester) async {
    gateway.page = pageOf([location(description: null)]);
    await pumpPage(tester);

    expect(find.text('Raio de 100 m'), findsOneWidget);
  });

  testWidgets('erro mostra a mensagem do motivo e tenta de novo', (
    tester,
  ) async {
    gateway.listFailure = LocationFailureReason.unavailable;
    await pumpPage(tester);

    expect(find.text('Não foi possível carregar'), findsOneWidget);
    expect(
      find.text(
        'O serviço de locais está fora do ar. Tente novamente em instantes.',
      ),
      findsOneWidget,
    );
    expect(find.text('Tentar novamente'), findsOneWidget);

    gateway.listFailure = null;
    gateway.page = pageOf([location(name: 'Portaria Norte')]);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pumpAndSettle();

    expect(find.text('Não foi possível carregar'), findsNothing);
    expect(find.text('Portaria Norte'), findsOneWidget);
  });

  testWidgets('erro fora do contrato usa a mensagem genérica', (tester) async {
    gateway.listCrash = StateError('boom');
    await pumpPage(tester);

    expect(
      find.text('Não foi possível carregar os locais. Tente novamente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('não-admin vê o motivo em vez da ação de criar', (tester) async {
    await pumpPage(tester, role: UserRole.resident);

    expect(find.text('Novo local'), findsNothing);
    expect(find.textContaining('Só administradores cadastram locais'),
        findsOneWidget);
    expect(gateway.listCalls, 1);
  });

  testWidgets('Novo local abre o formulário e voltar retorna à lista', (
    tester,
  ) async {
    await pumpPage(tester);

    await tester.tap(find.text('Novo local'));
    await tester.pumpAndSettle();

    expect(find.byType(NewLocationPage), findsOneWidget);
    expect(
      find.text(
        'Identifique o local e informe o endereço do ponto de acesso.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('back-to-locations')));
    await tester.pumpAndSettle();

    expect(find.byType(NewLocationPage), findsNothing);
    expect(find.text('Locais de acesso'), findsOneWidget);
  });

  testWidgets('local criado volta para a lista já atualizada', (tester) async {
    await pumpPage(tester);

    await tester.tap(find.text('Novo local'));
    await tester.pumpAndSettle();

    gateway.page = pageOf([location(name: 'Portaria Norte')]);

    await tester.enterText(
      find.byKey(const Key('field-name')),
      'Portaria Norte',
    );
    await tester.enterText(find.byKey(const Key('field-latitude')), '-23,18');
    await tester.enterText(find.byKey(const Key('field-longitude')), '-45,88');
    await tester.enterText(find.byKey(const Key('field-radius')), '80');
    await tester.tap(find.byKey(const Key('save-location-action')));
    await tester.pumpAndSettle();

    expect(find.byType(NewLocationPage), findsNothing);
    expect(find.text('Portaria Norte'), findsOneWidget);
    expect(gateway.created.single.name, 'Portaria Norte');
    expect(gateway.created.single.radiusMeters, 80);
    expect(gateway.listCalls, 2);
  });

  for (final scale in [1.3, 2.0]) {
    testWidgets('lista e ação não estouram com fonte ${scale}x em 360x640', (
      tester,
    ) async {
      gateway.page = pageOf([
        location(),
        location(
          id: 'outro',
          name: 'Edifício Aurora · Garagem',
          description: 'Av. Central, 1200 · subsolo',
        ),
      ]);
      await pumpPage(
        tester,
        size: const Size(360, 640),
        textScale: scale,
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('estado vazio não estoura com fonte 1.3x em 360x640', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(360, 640), textScale: 1.3);

    expect(find.text('Nenhum local cadastrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
