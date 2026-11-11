import '../scanner/access_contract.dart' show AccessDecision, DenialReason;

/// Recorte de `GET /access-events` (ADMIN) que a aba Histórico usa.
///
/// `AccessDecision` e `DenialReason` vêm do contrato do scanner (mesmo
/// `AccessEvent` da US-21): o histórico só acrescenta os textos que a tela
/// mostra, sem uma segunda cópia dos códigos da API.

enum AccessMethod {
  qr('QR', 'QR Code'),
  nfc('NFC', 'NFC (aproximação)');

  const AccessMethod(this.code, this.label);

  final String code;
  final String label;

  static AccessMethod fromCode(Object? code) => values.firstWhere(
    (method) => method.code == code,
    orElse: () => throw FormatException('Metodo de acesso desconhecido: $code'),
  );
}

/// Filtro da aba Histórico. `Todos` não manda o parâmetro `decision`.
enum AccessDecisionFilter {
  all('Todos'),
  granted('Liberados'),
  denied('Negados');

  const AccessDecisionFilter(this.label);

  final String label;

  AccessDecision? get decision => switch (this) {
    AccessDecisionFilter.all => null,
    AccessDecisionFilter.granted => AccessDecision.granted,
    AccessDecisionFilter.denied => AccessDecision.denied,
  };
}

/// Texto do motivo da negativa para quem não conhece os códigos da API.
extension DenialReasonLabel on DenialReason {
  String get label => switch (this) {
    DenialReason.invalidCredential => 'Credencial inválida',
    DenialReason.credentialExpired => 'QR Code fora da validade',
    DenialReason.userInactive => 'Conta desativada',
    DenialReason.noAuthorization => 'Sem autorização',
    DenialReason.authorizationNotStarted => 'Autorização ainda não começou',
    DenialReason.authorizationExpired => 'Autorização expirada',
    DenialReason.authorizationCanceled => 'Autorização cancelada',
    DenialReason.noUsesLeft => 'Sem usos restantes',
    DenialReason.outOfRange => 'Fora do raio do local',
    DenialReason.unknownTerminal => 'Terminal desconhecido',
    DenialReason.terminalInactive => 'Terminal desativado',
    DenialReason.unknown => 'Motivo não informado',
  };
}

/// Tentativa de acesso registrada, aceita ou negada.
class AdminAccessEvent {
  const AdminAccessEvent({
    required this.id,
    required this.occurredAt,
    required this.method,
    required this.decision,
    this.reason,
    this.personName,
    this.locationName,
  });

  factory AdminAccessEvent.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final occurredAt = json['occurredAt'];
    if (id is! String || id.trim().isEmpty || occurredAt is! String) {
      throw const FormatException('Evento de acesso fora do contrato');
    }
    final decision = switch (json['decision']) {
      'GRANTED' => AccessDecision.granted,
      'DENIED' => AccessDecision.denied,
      _ => throw const FormatException('Evento sem decisao valida'),
    };
    return AdminAccessEvent(
      id: id.trim(),
      // A API entrega UTC; a tela mostra no fuso do aparelho.
      occurredAt: DateTime.parse(occurredAt).toUtc(),
      method: AccessMethod.fromCode(json['method']),
      decision: decision,
      // Negativa sem motivo conhecido vira "Motivo não informado" em vez de
      // derrubar a lista inteira.
      reason: decision == AccessDecision.denied
          ? DenialReason.fromCode(json['reason'])
          : null,
      personName: _nameOf(json['user']),
      locationName: _nameOf(json['location']),
    );
  }

  final String id;
  final DateTime occurredAt;
  final AccessMethod method;
  final AccessDecision decision;

  /// Só vem preenchido quando a decisão é negativa.
  final DenialReason? reason;

  /// `null` quando a credencial não identifica ninguém (ex.: tag NFC órfã).
  final String? personName;

  /// `null` quando o terminal não tem local resolvido.
  final String? locationName;

  String get personLabel => personName ?? 'Credencial não identificada';

  String get locationLabel => locationName ?? 'Local não identificado';

  String get decisionLabel =>
      decision == AccessDecision.granted ? 'Liberado' : 'Negado';

  /// Linha única para o leitor de tela, com o motivo só quando negado.
  String accessibleLabel({required DateTime now}) {
    final reason = this.reason;
    final person = personName ?? 'credencial não identificada';
    return '$decisionLabel, $person, ${method.label}, $locationLabel'
        '${reason == null ? '' : ', motivo: ${reason.label}'}. '
        '${accessEventTimeLabel(occurredAt: occurredAt, now: now)}.';
  }
}

/// `UserSummary`/`LocationSummary` embutidos no evento: só o nome interessa.
String? _nameOf(Object? summary) {
  if (summary is! Map<String, dynamic>) return null;
  final name = summary['name'];
  return name is String && name.trim().isNotEmpty ? name.trim() : null;
}

/// Envelope paginado `{ items, page, pageSize, total }`.
class AdminAccessEventPage {
  const AdminAccessEventPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory AdminAccessEventPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final page = json['page'];
    final pageSize = json['pageSize'];
    final total = json['total'];
    if (items is! List || page is! int || pageSize is! int || total is! int) {
      throw const FormatException('AdminAccessEventPage fora do contrato');
    }
    return AdminAccessEventPage(
      items: [
        for (final item in items)
          if (item is Map<String, dynamic>)
            AdminAccessEvent.fromJson(item)
          else
            throw const FormatException('Item da pagina fora do contrato'),
      ],
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  final List<AdminAccessEvent> items;
  final int page;
  final int pageSize;
  final int total;
}

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "Hoje · 14:32" no fuso do aparelho; dias anteriores levam a data.
String accessEventTimeLabel({
  required DateTime occurredAt,
  required DateTime now,
}) {
  final local = occurredAt.toLocal();
  final today = now.toLocal();
  final sameDay =
      local.year == today.year &&
      local.month == today.month &&
      local.day == today.day;
  final date = sameDay
      ? 'Hoje'
      : local.year == today.year
      ? '${_twoDigits(local.day)}/${_twoDigits(local.month)}'
      : '${_twoDigits(local.day)}/${_twoDigits(local.month)}/${local.year}';
  return '$date · ${_twoDigits(local.hour)}:${_twoDigits(local.minute)}';
}

enum AccessEventsFailureReason {
  /// 401: token recusado; o cliente autenticado encerra a sessão.
  unauthorized,

  /// 403: perfil sem permissão (o histórico completo é só de ADMIN).
  forbidden,

  /// 400: o contrato recusou a consulta.
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

class AccessEventsFailure implements Exception {
  const AccessEventsFailure(this.reason);

  final AccessEventsFailureReason reason;

  @override
  String toString() => 'AccessEventsFailure(${reason.name})';
}

abstract interface class AccessEventsGateway {
  Future<AdminAccessEventPage> list({
    AccessDecision? decision,
    int page,
    int pageSize,
  });
}
