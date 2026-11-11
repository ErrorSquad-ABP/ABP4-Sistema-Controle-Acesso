import 'dart:async';

import 'package:controle_acesso/features/authorizations/authorization_contract.dart';

/// Autorização de teste no fuso do aparelho entre 14h e 18h.
Authorization authorization({
  String id = '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  String locationName = 'Edifício Aurora · Recepção',
  AuthorizationStatus status = AuthorizationStatus.active,
  DateTime? startsAt,
  DateTime? endsAt,
  int maxUses = 5,
  int remainingUses = 3,
}) {
  final start = startsAt ?? DateTime(2026, 10, 27, 14);
  return Authorization(
    id: id,
    locationName: locationName,
    startsAt: start.toUtc(),
    endsAt: (endsAt ?? DateTime(2026, 10, 27, 18)).toUtc(),
    maxUses: maxUses,
    remainingUses: remainingUses,
    status: status,
  );
}

AuthorizationPage pageOf(List<Authorization> items) => AuthorizationPage(
  items: items,
  page: 1,
  pageSize: 100,
  total: items.length,
);

/// Responde sem rede. `gate` segura a resposta para o teste ver o carregando.
class FakeAuthorizationGateway implements AuthorizationGateway {
  AuthorizationPage page = pageOf([]);

  AuthorizationFailureReason? failure;

  /// Erro fora do contrato, para checar que a tela não quebra.
  Object? crash;

  Completer<void>? gate;

  int calls = 0;
  int lastPage = 0;
  int lastPageSize = 0;

  @override
  Future<AuthorizationPage> listMine({int page = 1, int pageSize = 100}) async {
    calls++;
    lastPage = page;
    lastPageSize = pageSize;
    await gate?.future;
    final crash = this.crash;
    if (crash != null) throw crash;
    final failure = this.failure;
    if (failure != null) throw AuthorizationFailure(failure);
    return this.page;
  }
}
