import '../auth/auth_contract.dart';

/// Recorte de `GET/POST/PATCH/DELETE /users` (US-15, US-31) que as telas usam.
///
/// O contrato devolve o `User` inteiro, mas a administração só mostra e edita
/// nome, e-mail, perfil e situação: as datas de criação não aparecem em
/// nenhuma tela e ficam de fora do modelo.
class AdminUser {
  const AdminUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final email = json['email'];
    final active = json['active'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        email is! String ||
        email.trim().isEmpty ||
        active is! bool) {
      throw const FormatException('Usuario fora do contrato');
    }
    return AdminUser(
      id: id.trim(),
      name: name.trim(),
      email: email.trim(),
      role: UserRole.fromCode(json['role']),
      active: active,
    );
  }

  final String id;
  final String name;
  final String email;
  final UserRole role;
  final bool active;

  /// Primeira e última inicial, como no avatar do Perfil.
  String get initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '';
    final first = parts.first.substring(0, 1);
    final last = parts.length > 1 ? parts.last.substring(0, 1) : '';
    return '$first$last'.toUpperCase();
  }

  /// Uma linha por cartão, sem repetir o que já está escrito na tela.
  String get accessibleLabel =>
      '$name, $email, ${role.label}, '
      '${active ? 'conta ativa' : 'conta inativa'}. '
      'Toque para abrir e editar.';
}

/// Envelope paginado `{ items, page, pageSize, total }`.
class AdminUserPage {
  const AdminUserPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AdminUserPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final page = json['page'];
    final pageSize = json['pageSize'];
    final total = json['total'];
    if (items is! List || page is! int || pageSize is! int || total is! int) {
      throw const FormatException('AdminUserPage fora do contrato');
    }
    return AdminUserPage(
      items: [
        for (final item in items)
          if (item is Map<String, dynamic>)
            AdminUser.fromJson(item)
          else
            throw const FormatException('Item da pagina fora do contrato'),
      ],
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  final List<AdminUser> items;
  final int page;
  final int pageSize;
  final int total;
}

/// Corpo de `POST /users`. Os limites espelham o zod do backend
/// (`CreateUserRequest`): a validação local evita um 400 previsível.
class CreateAdminUserRequest {
  CreateAdminUserRequest({
    required String name,
    required String email,
    required this.password,
    required this.role,
  }) : name = name.trim(),
       email = email.trim().toLowerCase();

  final String name;
  final String email;
  final String password;
  final UserRole role;

  Map<String, Object> toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'role': role.code,
  };
}

/// Corpo de `PATCH /users/:id` com o que a tela edita. E-mail e senha ficam de
/// fora: trocar a senha de outra pessoa não é fluxo desta entrega.
class UpdateAdminUserRequest {
  UpdateAdminUserRequest({
    required String name,
    required this.role,
    required this.active,
  }) : name = name.trim();

  final String name;
  final UserRole role;
  final bool active;

  Map<String, Object> toJson() => {
    'name': name,
    'role': role.code,
    'active': active,
  };
}

abstract final class AdminUserValidation {
  static const int minPasswordLength = 8;
  static const int maxPasswordLength = 72;

  static String? name(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Informe o nome da pessoa.';
    if (name.length < 2) return 'O nome deve ter pelo menos 2 caracteres.';
    if (name.length > 120) return 'O nome deve ter até 120 caracteres.';
    return null;
  }

  /// Mesmo formato e limite de `LoginValidation.email`: a regra do login é a
  /// regra do cadastro, e uma única cópia evita as duas divergirem.
  static String? email(String? value) => LoginValidation.email(value);

  static String? password(String? value) {
    final password = value ?? '';
    if (password.isEmpty) return 'Crie uma senha para a pessoa.';
    if (password.length < minPasswordLength) {
      return 'A senha deve ter pelo menos $minPasswordLength caracteres.';
    }
    if (password.length > maxPasswordLength) {
      return 'A senha deve ter até $maxPasswordLength caracteres.';
    }
    return null;
  }
}

enum AdminUsersFailureReason {
  /// 401: token recusado; o cliente autenticado encerra a sessão.
  unauthorized,

  /// 403: perfil sem permissão (as rotas de usuários são só de ADMIN).
  forbidden,

  /// 404 (ou id inválido): a conta não existe mais.
  notFound,

  /// 409: e-mail já cadastrado ou última administradora ativa.
  conflict,

  /// 400: o contrato recusou os dados enviados.
  invalidRequest,

  /// 429 ou 5xx: backend fora, sem banco ou pedindo calma.
  unavailable,

  /// Sem resposta: sem rede ou DNS.
  network,

  /// O servidor não respondeu dentro do prazo.
  timeout,

  /// Resposta fora do contrato.
  unexpected,
}

class AdminUsersFailure implements Exception {
  const AdminUsersFailure(this.reason);

  final AdminUsersFailureReason reason;

  @override
  String toString() => 'AdminUsersFailure(${reason.name})';
}

abstract interface class AdminUsersGateway {
  Future<AdminUserPage> list({String search, int page, int pageSize});

  Future<AdminUser> findById(String id);

  Future<AdminUser> create(CreateAdminUserRequest request);

  Future<AdminUser> update(String id, UpdateAdminUserRequest request);

  /// `DELETE /users/:id`: exclusão lógica, o histórico de acessos permanece.
  Future<void> delete(String id);
}
