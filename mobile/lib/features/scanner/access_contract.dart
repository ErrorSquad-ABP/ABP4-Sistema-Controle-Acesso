import 'package:flutter/foundation.dart';

import 'scanner_contracts.dart';

/// Mesma regra do backend (`TERMINAL_ID_PATTERN`): 1 a 64 caracteres,
/// minúsculas, números e hífen, começando por alfanumérico.
final _terminalIdPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');

/// Extrai o terminal do QR rotativo do terminal.
///
/// O formato é `v1.<terminalId>.<iat>.<exp>.<assinatura>` (US-19). O app só
/// lê o terminal para montar o pedido: autenticidade, validade e a conferência
/// do terminal são do backend. Devolve `null` para qualquer outro texto.
String? terminalIdFromQrToken(String token) {
  final parts = token.trim().split('.');
  if (parts.length != 5 || parts.first != 'v1') return null;
  final terminalId = parts[1];
  return _terminalIdPattern.hasMatch(terminalId) ? terminalId : null;
}

/// Lê o código curto do QR compacto (41 dígitos) sem passar por `double`.
///
/// O código não autentica nada: o backend confere a assinatura HMAC embutida e
/// resolve o terminal real. Devolve `null` para qualquer texto fora do formato.
int? terminalCodeFromQrToken(String token) {
  final value = token.trim();
  if (!RegExp(r'^[0-9]{41}$').hasMatch(value)) return null;
  final packed = BigInt.parse(value);
  if (packed >= (BigInt.one << 136)) return null;
  final code = (packed >> 128).toInt();
  return code == 0 ? null : code;
}

/// `POST /access-events/qr` do contrato v1 (US-20): o que o app envia.
@immutable
class QrAccessRequest {
  const QrAccessRequest({
    required this.qrToken,
    this.terminalId,
    this.terminalCode,
    required this.position,
    required this.requestId,
  }) : assert(
          (terminalId == null) != (terminalCode == null),
          'envie terminalId legado ou terminalCode compacto, nunca os dois',
        );

  final String qrToken;

  /// Referência do QR textual v1; nula quando o QR é compacto.
  final String? terminalId;

  /// Código curto do QR compacto; nulo no formato textual v1.
  final int? terminalCode;

  final GeoCoordinate position;

  /// Chave de idempotência da tentativa: repetir o mesmo valor devolve o mesmo
  /// evento, sem consumir a autorização de novo.
  final String requestId;

  Map<String, Object> toJson() => {
    'qrToken': qrToken,
    'terminalId': ?terminalId,
    'terminalCode': ?terminalCode,
    'position': {
      'latitude': position.latitude,
      'longitude': position.longitude,
      if (position.accuracyMeters != null)
        'accuracyMeters': position.accuracyMeters!,
    },
    'requestId': requestId,
  };
}

enum AccessDecision { granted, denied }

/// Motivos de negativa do contrato (`DenialReason`). Um valor que o app não
/// conhece vira [unknown], com texto genérico, em vez de derrubar a tela.
enum DenialReason {
  invalidCredential('INVALID_CREDENTIAL'),
  credentialExpired('CREDENTIAL_EXPIRED'),
  userInactive('USER_INACTIVE'),
  noAuthorization('NO_AUTHORIZATION'),
  authorizationNotStarted('AUTHORIZATION_NOT_STARTED'),
  authorizationExpired('AUTHORIZATION_EXPIRED'),
  authorizationCanceled('AUTHORIZATION_CANCELED'),
  noUsesLeft('NO_USES_LEFT'),
  outOfRange('OUT_OF_RANGE'),
  unknownTerminal('UNKNOWN_TERMINAL'),
  terminalInactive('TERMINAL_INACTIVE'),
  unknown('');

  const DenialReason(this.code);

  final String code;

  static DenialReason fromCode(Object? code) => values.firstWhere(
    (reason) => reason.code.isNotEmpty && reason.code == code,
    orElse: () => unknown,
  );
}

/// Recorte da `AccessResult` que a tela de resultado usa.
@immutable
class AccessResult {
  const AccessResult({
    required this.decision,
    required this.reason,
    required this.occurredAt,
    this.locationName,
  });

  factory AccessResult.fromJson(Map<String, dynamic> json) {
    final decision = switch (json['decision']) {
      'GRANTED' => AccessDecision.granted,
      'DENIED' => AccessDecision.denied,
      _ => throw const FormatException('AccessResult sem decisão válida'),
    };
    final event = json['event'];
    if (event is! Map<String, dynamic>) {
      throw const FormatException('AccessResult sem evento');
    }
    final occurredAt = event['occurredAt'];
    if (occurredAt is! String) {
      throw const FormatException('Evento sem data');
    }
    final location = event['location'];
    final name = location is Map<String, dynamic> ? location['name'] : null;
    return AccessResult(
      decision: decision,
      reason: decision == AccessDecision.denied
          ? DenialReason.fromCode(json['reason'])
          : null,
      // Data ilegível também sai como FormatException.
      occurredAt: DateTime.parse(occurredAt).toUtc(),
      locationName: name is String && name.trim().isNotEmpty
          ? name.trim()
          : null,
    );
  }

  final AccessDecision decision;

  /// Só vem preenchido quando a decisão é negativa.
  final DenialReason? reason;
  final DateTime occurredAt;
  final String? locationName;
}

enum AccessFailureReason {
  /// 401: sessão recusada. O cliente autenticado já encerra a sessão.
  unauthorized,

  /// 400: o backend recusou o pedido.
  invalidRequest,

  /// 429: limite de requisições.
  tooManyRequests,

  /// 503 ou 5xx: backend ou banco fora do ar.
  unavailable,

  /// Sem resposta: sem rede ou DNS.
  network,

  /// O servidor não respondeu dentro do prazo.
  timeout,

  /// Resposta fora do contrato.
  unexpected,
}

class AccessFailure implements Exception {
  const AccessFailure(this.reason);

  final AccessFailureReason reason;

  @override
  String toString() => 'AccessFailure(${reason.name})';
}

/// Pedido de acesso por QR ao backend.
abstract interface class AccessGateway {
  Future<AccessResult> requestQrAccess(QrAccessRequest request);
}
