import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes.dart';

void main() {
  group('AdminUser', () {
    test('lê o contrato e monta iniciais e rótulo de leitura', () {
      final user = AdminUser.fromJson({
        'id': 'c1f2a3b4-1111-4222-8333-944455556666',
        'name': ' Maria Souza ',
        'email': ' maria.souza@exemplo.com ',
        'role': 'ADMIN',
        'active': false,
        'createdAt': '2026-11-10T12:00:00.000Z',
        'updatedAt': '2026-11-10T12:00:00.000Z',
      });

      expect(user.name, 'Maria Souza');
      expect(user.email, 'maria.souza@exemplo.com');
      expect(user.role, UserRole.admin);
      expect(user.active, isFalse);
      expect(user.initials, 'MS');
      expect(
        user.accessibleLabel,
        'Maria Souza, maria.souza@exemplo.com, Administrador, conta inativa. '
        'Toque para abrir e editar.',
      );
    });

    for (final (nome, json) in [
      (
        'sem id',
        <String, Object?>{
          'name': 'Maria',
          'email': 'm@x.com',
          'role': 'ADMIN',
          'active': true,
        },
      ),
      (
        'nome vazio',
        <String, Object?>{
          'id': 'id',
          'name': ' ',
          'email': 'm@x.com',
          'role': 'ADMIN',
          'active': true,
        },
      ),
      (
        'e-mail vazio',
        <String, Object?>{
          'id': 'id',
          'name': 'Maria',
          'email': '',
          'role': 'ADMIN',
          'active': true,
        },
      ),
      (
        'situação que não é booleana',
        <String, Object?>{
          'id': 'id',
          'name': 'Maria',
          'email': 'm@x.com',
          'role': 'ADMIN',
          'active': 1,
        },
      ),
      (
        'papel desconhecido',
        <String, Object?>{
          'id': 'id',
          'name': 'Maria',
          'email': 'm@x.com',
          'role': 'OWNER',
          'active': true,
        },
      ),
    ]) {
      test('recusa $nome', () {
        expect(
          () => AdminUser.fromJson(json.cast<String, dynamic>()),
          throwsFormatException,
        );
      });
    }

    test('página recusa item que não é objeto', () {
      expect(
        () => AdminUserPage.fromJson({
          'items': ['x'],
          'page': 1,
          'pageSize': 100,
          'total': 1,
        }),
        throwsFormatException,
      );
    });
  });

  group('validação', () {
    test('nome entre 2 e 120', () {
      expect(AdminUserValidation.name(''), isNotNull);
      expect(AdminUserValidation.name(' A '), isNotNull);
      expect(AdminUserValidation.name('A' * 121), isNotNull);
      expect(AdminUserValidation.name('Maria Souza'), isNull);
    });

    test('e-mail usa a mesma regra do login', () {
      expect(AdminUserValidation.email('sem-arroba'), isNotNull);
      expect(AdminUserValidation.email('maria.souza@exemplo.com'), isNull);
    });

    test('senha entre 8 e 72', () {
      expect(AdminUserValidation.password(''), isNotNull);
      expect(AdminUserValidation.password('1234567'), isNotNull);
      expect(AdminUserValidation.password('12345678'), isNull);
      expect(AdminUserValidation.password('x' * 72), isNull);
      expect(AdminUserValidation.password('x' * 73), isNotNull);
    });
  });

  group('corpos das requisições', () {
    test('cadastro apara o nome e normaliza o e-mail', () {
      final request = CreateAdminUserRequest(
        name: '  Renata Alves ',
        email: ' Renata.Alves@Exemplo.com ',
        password: 'senha-forte-123',
        role: UserRole.visitor,
      );

      expect(request.toJson(), {
        'name': 'Renata Alves',
        'email': 'renata.alves@exemplo.com',
        'password': 'senha-forte-123',
        'role': 'VISITOR',
      });
    });

    test('edição envia nome, perfil e situação', () {
      final request = UpdateAdminUserRequest(
        name: ' Maria Souza ',
        role: UserRole.admin,
        active: false,
      );

      expect(request.toJson(), {
        'name': 'Maria Souza',
        'role': 'ADMIN',
        'active': false,
      });
    });
  });

  test('página vazia do controlador tem o envelope do contrato', () {
    const empty = AdminUserPage(items: [], page: 1, pageSize: 0, total: 0);
    expect(empty.items, isEmpty);
    expect(empty.total, 0);
  });

  test('fixture do teste acompanha o contrato', () {
    final user = userAccount(name: 'Renata Alves', role: UserRole.visitor);
    expect(user.initials, 'RA');
    expect(user.role.label, 'Visitante');
    expect(usersPageOf([user]).total, 1);
  });
}
