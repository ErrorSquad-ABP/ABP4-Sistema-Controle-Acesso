import '../auth/auth_contract.dart';
import '../authorizations/authorization_contract.dart';

/// Recorte de ADMIN de `/authorizations` (US-30) que as telas usam.
///
/// A autorização devolvida é o mesmo `Authorization` de `GET
/// /me/authorizations`: o contrato não tem campo extra para o administrador.
/// `usedCount`, `canceledAt` e `cancelReason` existem na API, mas nenhuma
/// tela desta entrega os mostra — o app não os lê.

/// Filtro de situação da lista. A situação vai como `status` de
/// `GET /authorizations`; `null` pede todas.
enum AdminAuthorizationFilter {
  all('Todas', null),
  scheduled('Agendadas', AuthorizationStatus.scheduled),
  active('Ativas', AuthorizationStatus.active),
  expired('Expiradas', AuthorizationStatus.expired),
  canceled('Canceladas', AuthorizationStatus.canceled);

  const AdminAuthorizationFilter(this.label, this.status);

  final String label;
  final AuthorizationStatus? status;
}

/// O backend recusa com 409 o cancelamento de uma autorização cancelada ou
/// expirada (`CancelAuthorizationUseCase`); a tela só oferece a ação onde ela
/// pode dar certo.
bool canCancelAuthorization(AuthorizationStatus status) =>
    status == AuthorizationStatus.scheduled ||
    status == AuthorizationStatus.active;

const String _accented = 'áàâãäéèêëíìîïóòôõöúùûüç';
const String _plain = 'aaaaaeeeeiiiiooooouuuuc';

/// Minúsculas e sem acento: a busca por pessoa ou local não depende de como o
/// administrador digita o nome.
String searchFold(String value) {
  final lower = value.toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    final index = _accented.indexOf(char);
    buffer.write(index < 0 ? char : _plain[index]);
  }
  return buffer.toString();
}

/// Pessoa do diretório de `GET /users` (US-15): o recorte do seletor do
/// formulário.
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
      throw const FormatException('User fora do contrato');
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

  /// "Maria Souza · maria@exemplo.com · Condômino", como no seletor.
  String get display => '$name · $email · ${role.label}';
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
      throw const FormatException('UserPage fora do contrato');
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

/// Corpo de `POST /authorizations`. A janela vai em UTC: a API aceita offset,
/// mas o fuso do aparelho não precisa aparecer na requisição.
class CreateAuthorizationRequest {
  const CreateAuthorizationRequest({
    required this.userId,
    required this.locationId,
    required this.startsAt,
    required this.endsAt,
    required this.maxUses,
  });

  final String userId;
  final String locationId;
  final DateTime startsAt;
  final DateTime endsAt;
  final int maxUses;

  Map<String, Object> toJson() => {
    'userId': userId,
    'locationId': locationId,
    'startsAt': startsAt.toUtc().toIso8601String(),
    'endsAt': endsAt.toUtc().toIso8601String(),
    'maxUses': maxUses,
  };
}

/// Validação local espelhando o zod do backend (`CreateAuthorizationRequest` e
/// `CancelAuthorizationRequest`): fim depois do início, 1..1000 usos e motivo
/// até 280 caracteres. O 400 previsível não sai do aparelho.
abstract final class AdminAuthorizationValidation {
  static const int minMaxUses = 1;
  static const int maxMaxUses = 1000;
  static const int maxReasonLength = 280;

  static String? person(Object? value) =>
      value == null ? 'Escolha a pessoa.' : null;

  static String? location(Object? value) =>
      value == null ? 'Escolha o local.' : null;

  static String? window(DateTime? startsAt, DateTime? endsAt) {
    if (startsAt == null) return 'Informe o início da janela.';
    if (endsAt == null) return 'Informe o fim da janela.';
    if (!endsAt.isAfter(startsAt)) return 'O fim deve ser depois do início.';
    return null;
  }

  static String? maxUses(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Informe o máximo de usos.';
    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Informe o máximo de usos em números inteiros.';
    if (parsed < minMaxUses || parsed > maxMaxUses) {
      return 'O máximo de usos deve ficar entre 1 e 1000.';
    }
    return null;
  }

  static int? parseMaxUses(String? value) => int.tryParse((value ?? '').trim());

  static String? cancelReason(String? value) {
    final reason = (value ?? '').trim();
    if (reason.isEmpty) return 'Informe o motivo do cancelamento.';
    if (reason.length > maxReasonLength) {
      return 'O motivo deve ter até $maxReasonLength caracteres.';
    }
    return null;
  }
}

enum AdminFailureReason {
  /// 401: token recusado; o cliente autenticado encerra a sessão.
  unauthorized,

  /// 403: perfil sem permissão de administração.
  forbidden,

  /// 404: a autorização não existe mais.
  notFound,

  /// 409: cancelamento de uma autorização que já acabou.
  conflict,

  /// 400: o contrato recusou o corpo enviado.
  invalidRequest,

  /// 422: a pessoa ou o local escolhidos não existem mais.
  unprocessable,

  /// 5xx ou 429: backend fora, sem banco ou pedindo calma.
  unavailable,

  /// Sem resposta: sem rede ou DNS.
  network,

  /// O servidor não respondeu dentro do prazo.
  timeout,

  /// Resposta fora do contrato.
  unexpected,
}

class AdminFailure implements Exception {
  const AdminFailure(this.reason);

  final AdminFailureReason reason;

  @override
  String toString() => 'AdminFailure(${reason.name})';
}

abstract interface class AdminAuthorizationGateway {
  Future<AuthorizationPage> list({
    int page,
    int pageSize,
    AuthorizationStatus? status,
  });

  Future<Authorization> create(CreateAuthorizationRequest request);

  Future<Authorization> cancel(String id, String reason);
}

abstract interface class AdminUserGateway {
  Future<AdminUserPage> list({
    String? search,
    int page,
    int pageSize,
    bool? active,
  });
}
