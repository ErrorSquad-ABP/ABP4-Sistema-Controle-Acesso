import 'dart:convert';

import 'package:controle_acesso/features/admin_authorizations/admin_authorization_contract.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CreateAuthorizationRequest', () {
    test('manda a janela em UTC e o máximo de usos', () {
      final local = DateTime(2026, 11, 20, 14);
      final request = CreateAuthorizationRequest(
        userId: '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
        locationId: 'c1f2a3b4-1111-4222-8333-944455556666',
        startsAt: local,
        endsAt: local.add(const Duration(hours: 4)),
        maxUses: 5,
      );

      final body = request.toJson();
      expect(body['userId'], '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11');
      expect(body['locationId'], 'c1f2a3b4-1111-4222-8333-944455556666');
      expect(body['maxUses'], 5);
      expect(body['startsAt'], local.toUtc().toIso8601String());
      expect(
        body['endsAt'],
        local.add(const Duration(hours: 4)).toUtc().toIso8601String(),
      );
      // O contrato aceita offset, mas UTC dispensa o fuso do aparelho.
      expect((body['startsAt']! as String).endsWith('Z'), isTrue);
    });
  });

  group('janela', () {
    final start = DateTime(2026, 11, 20, 14);

    test('recusa início e fim ausentes', () {
      expect(
        AdminAuthorizationValidation.window(null, start),
        'Informe o início da janela.',
      );
      expect(
        AdminAuthorizationValidation.window(start, null),
        'Informe o fim da janela.',
      );
    });

    test('exige fim depois do início', () {
      expect(
        AdminAuthorizationValidation.window(start, start),
        'O fim deve ser depois do início.',
      );
      expect(
        AdminAuthorizationValidation.window(
          start,
          start.subtract(const Duration(minutes: 1)),
        ),
        'O fim deve ser depois do início.',
      );
      expect(
        AdminAuthorizationValidation.window(
          start,
          start.add(const Duration(minutes: 1)),
        ),
        isNull,
      );
    });
  });

  group('máximo de usos', () {
    test('aceita o intervalo do contrato', () {
      expect(AdminAuthorizationValidation.maxUses('1'), isNull);
      expect(AdminAuthorizationValidation.maxUses('1000'), isNull);
      expect(AdminAuthorizationValidation.parseMaxUses(' 42 '), 42);
    });

    test('recusa vazio, texto e fora de 1..1000', () {
      expect(
        AdminAuthorizationValidation.maxUses(' '),
        'Informe o máximo de usos.',
      );
      expect(
        AdminAuthorizationValidation.maxUses('abc'),
        'Informe o máximo de usos em números inteiros.',
      );
      expect(
        AdminAuthorizationValidation.maxUses('0'),
        'O máximo de usos deve ficar entre 1 e 1000.',
      );
      expect(
        AdminAuthorizationValidation.maxUses('1001'),
        'O máximo de usos deve ficar entre 1 e 1000.',
      );
    });
  });

  group('motivo do cancelamento', () {
    test('obrigatório e até 280 caracteres', () {
      expect(
        AdminAuthorizationValidation.cancelReason('   '),
        'Informe o motivo do cancelamento.',
      );
      expect(
        AdminAuthorizationValidation.cancelReason('a' * 281),
        'O motivo deve ter até 280 caracteres.',
      );
      expect(
        AdminAuthorizationValidation.cancelReason('Visita remarcada'),
        isNull,
      );
    });
  });

  group('pessoa e local', () {
    test('exigem escolha', () {
      expect(AdminAuthorizationValidation.person(null), 'Escolha a pessoa.');
      expect(AdminAuthorizationValidation.location(null), 'Escolha o local.');
      expect(AdminAuthorizationValidation.person('id'), isNull);
      expect(AdminAuthorizationValidation.location('id'), isNull);
    });
  });

  group('searchFold', () {
    test('ignora caixa e acentos', () {
      expect(searchFold('Edifício AURORA'), 'edificio aurora');
      expect(searchFold('João Conceição'), 'joao conceicao');
    });
  });

  group('cancelamento', () {
    test('só agendada e ativa podem ser canceladas', () {
      expect(canCancelAuthorization(AuthorizationStatus.scheduled), isTrue);
      expect(canCancelAuthorization(AuthorizationStatus.active), isTrue);
      expect(canCancelAuthorization(AuthorizationStatus.expired), isFalse);
      expect(canCancelAuthorization(AuthorizationStatus.canceled), isFalse);
    });
  });

  group('AdminUser', () {
    Map<String, Object?> json({
      Object? id = '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
      Object? name = 'Maria Souza',
      Object? email = 'maria.souza@exemplo.com',
      Object? role = 'VISITOR',
      Object? active = true,
    }) => {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'active': active,
      'createdAt': '2026-11-10T12:00:00.000Z',
      'updatedAt': '2026-11-10T12:00:00.000Z',
    };

    test('lê o usuário e o resumo do seletor', () {
      final user = AdminUser.fromJson(json() as Map<String, dynamic>);

      expect(user.id, '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11');
      expect(user.name, 'Maria Souza');
      expect(user.role, UserRole.visitor);
      expect(user.active, isTrue);
      expect(user.display, 'Maria Souza · maria.souza@exemplo.com · Visitante');
    });

    test('recusa campos fora do contrato', () {
      for (final body in [
        json(id: ''),
        json(name: ' '),
        json(email: ''),
        json(role: 'OWNER'),
        json(active: 'true'),
      ]) {
        expect(
          () => AdminUser.fromJson(body as Map<String, dynamic>),
          throwsFormatException,
        );
      }
    });

    test('lê a página paginada', () {
      final page = AdminUserPage.fromJson(
        jsonDecode(
          jsonEncode({
            'items': [json()],
            'page': 1,
            'pageSize': 100,
            'total': 1,
          }),
        ) as Map<String, dynamic>,
      );

      expect(page.items.single.name, 'Maria Souza');
      expect(page.total, 1);
    });

    test('recusa página fora do contrato', () {
      expect(
        () => AdminUserPage.fromJson({
          'items': 'x',
          'page': 1,
          'pageSize': 1,
          'total': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => AdminUserPage.fromJson({
          'items': [1],
          'page': 1,
          'pageSize': 1,
          'total': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('filtro', () {
    test('cada chip leva a situação do contrato', () {
      expect(AdminAuthorizationFilter.all.status, isNull);
      expect(
        AdminAuthorizationFilter.scheduled.status,
        AuthorizationStatus.scheduled,
      );
      expect(
        AdminAuthorizationFilter.active.status,
        AuthorizationStatus.active,
      );
      expect(
        AdminAuthorizationFilter.expired.status,
        AuthorizationStatus.expired,
      );
      expect(
        AdminAuthorizationFilter.canceled.status,
        AuthorizationStatus.canceled,
      );
    });
  });
}
