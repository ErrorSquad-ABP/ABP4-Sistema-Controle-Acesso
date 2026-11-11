/// Recorte de `GET /me/authorizations` (US-18) que a tela usa.
///
/// Situação é calculada pelo backend; o app só a apresenta. Os campos que a
/// lista não mostra (usuário, contagem de usos, cancelamento) ficam de fora.
enum AuthorizationStatus {
  scheduled('SCHEDULED', 'Agendada'),
  active('ACTIVE', 'Ativa'),
  expired('EXPIRED', 'Expirada'),
  canceled('CANCELED', 'Cancelada');

  const AuthorizationStatus(this.code, this.label);

  final String code;
  final String label;

  static AuthorizationStatus fromCode(Object? code) => values.firstWhere(
    (status) => status.code == code,
    orElse: () => throw FormatException('Situacao desconhecida: $code'),
  );
}

/// Abas do filtro da tela. O frame do Figma mostra uma autorização expirada
/// na aba Ativas: ela lista o que a API devolve. O Histórico é o recorte das
/// que já acabaram (expiradas ou canceladas), sem buscar outra fonte.
enum AuthorizationFilter {
  active('Ativas'),
  history('Histórico');

  const AuthorizationFilter(this.label);

  final String label;

  bool matches(AuthorizationStatus status) => switch (this) {
    AuthorizationFilter.active => true,
    AuthorizationFilter.history =>
      status == AuthorizationStatus.expired ||
          status == AuthorizationStatus.canceled,
  };
}

class Authorization {
  const Authorization({
    required this.id,
    required this.locationName,
    required this.startsAt,
    required this.endsAt,
    required this.maxUses,
    required this.remainingUses,
    required this.status,
  });

  factory Authorization.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final location = json['location'];
    final startsAt = json['startsAt'];
    final endsAt = json['endsAt'];
    final maxUses = json['maxUses'];
    final remainingUses = json['remainingUses'];
    if (id is! String ||
        id.trim().isEmpty ||
        location is! Map<String, dynamic> ||
        startsAt is! String ||
        endsAt is! String ||
        maxUses is! int ||
        maxUses < 1 ||
        remainingUses is! int ||
        remainingUses < 0) {
      throw const FormatException('Authorization fora do contrato');
    }
    final name = location['name'];
    if (name is! String || name.trim().isEmpty) {
      throw const FormatException('Local da autorizacao fora do contrato');
    }
    return Authorization(
      id: id.trim(),
      locationName: name.trim(),
      // A API entrega UTC; a tela mostra no fuso do aparelho.
      startsAt: DateTime.parse(startsAt).toUtc(),
      endsAt: DateTime.parse(endsAt).toUtc(),
      maxUses: maxUses,
      remainingUses: remainingUses,
      status: AuthorizationStatus.fromCode(json['status']),
    );
  }

  final String id;
  final String locationName;
  final DateTime startsAt;
  final DateTime endsAt;
  final int maxUses;
  final int remainingUses;
  final AuthorizationStatus status;

  /// Fração da barra de usos: o que ainda pode ser usado na janela.
  double get remainingFraction =>
      remainingUses >= maxUses ? 1 : remainingUses / maxUses;
}

/// Envelope paginado `{ items, page, pageSize, total }`.
class AuthorizationPage {
  const AuthorizationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AuthorizationPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final page = json['page'];
    final pageSize = json['pageSize'];
    final total = json['total'];
    if (items is! List || page is! int || pageSize is! int || total is! int) {
      throw const FormatException('AuthorizationPage fora do contrato');
    }
    return AuthorizationPage(
      items: [
        for (final item in items)
          if (item is Map<String, dynamic>)
            Authorization.fromJson(item)
          else
            throw const FormatException('Item da pagina fora do contrato'),
      ],
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  final List<Authorization> items;
  final int page;
  final int pageSize;
  final int total;
}

enum AuthorizationFailureReason {
  /// 401: token recusado; o cliente autenticado encerra a sessão.
  unauthorized,

  /// 5xx ou 429: backend fora, sem banco ou pedindo calma.
  unavailable,

  /// Sem resposta: sem rede ou DNS.
  network,

  /// O servidor não respondeu dentro do prazo.
  timeout,

  /// Resposta fora do contrato.
  unexpected,
}

class AuthorizationFailure implements Exception {
  const AuthorizationFailure(this.reason);

  final AuthorizationFailureReason reason;

  @override
  String toString() => 'AuthorizationFailure(${reason.name})';
}

abstract interface class AuthorizationGateway {
  Future<AuthorizationPage> listMine({int page, int pageSize});
}
