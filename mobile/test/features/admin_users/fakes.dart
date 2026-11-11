import 'dart:async';

import 'package:controle_acesso/features/admin_users/access_events_contract.dart';
import 'package:controle_acesso/features/admin_users/admin_users_contract.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/scanner/access_contract.dart'
    show AccessDecision, DenialReason;

/// Administradora da sessão: o perfil que a API aceita nas rotas de usuários.
const anaAdmin = AuthUser(
  id: '0d6a6f7e-1f2b-4c3d-8e4f-5a6b7c8d9e0f',
  name: 'Ana Lima',
  email: 'ana.lima@exemplo.com',
  role: UserRole.admin,
);

AdminUser userAccount({
  String id = 'c1f2a3b4-1111-4222-8333-944455556666',
  String name = 'Maria Souza',
  String email = 'maria.souza@exemplo.com',
  UserRole role = UserRole.resident,
  bool active = true,
}) => AdminUser(id: id, name: name, email: email, role: role, active: active);

AdminUserPage usersPageOf(List<AdminUser> items, {int? total}) => AdminUserPage(
  items: items,
  page: 1,
  pageSize: 100,
  total: total ?? items.length,
);

AdminAccessEvent accessEvent({
  String id = 'e1f2a3b4-1111-4222-8333-944455556666',
  DateTime? occurredAt,
  AccessMethod method = AccessMethod.qr,
  AccessDecision decision = AccessDecision.granted,
  DenialReason? reason,
  String? personName = 'Maria Souza',
  String? locationName = 'Edifício Aurora · Recepção',
}) => AdminAccessEvent(
  id: id,
  occurredAt: occurredAt ?? DateTime.utc(2026, 10, 27, 12),
  method: method,
  decision: decision,
  reason: reason,
  personName: personName,
  locationName: locationName,
);

AdminAccessEventPage eventsPageOf(List<AdminAccessEvent> items, {int? total}) =>
    AdminAccessEventPage(
      items: items,
      page: 1,
      pageSize: 100,
      total: total ?? items.length,
    );

/// Responde sem rede. Os `gate`s seguram a resposta para o teste ver o
/// carregando e o salvando.
class FakeAdminUsersGateway implements AdminUsersGateway {
  AdminUserPage page = usersPageOf([]);

  AdminUsersFailureReason? listFailure;
  AdminUsersFailureReason? detailFailure;
  AdminUsersFailureReason? createFailure;
  AdminUsersFailureReason? updateFailure;
  AdminUsersFailureReason? deleteFailure;

  /// Erro fora do contrato, para checar que a tela não quebra.
  Object? listCrash;
  Object? detailCrash;
  Object? createCrash;

  Completer<void>? listGate;
  Completer<void>? detailGate;
  Completer<void>? createGate;
  Completer<void>? updateGate;
  Completer<void>? deleteGate;

  int listCalls = 0;
  String lastSearch = '';
  int lastPageSize = 0;
  final List<CreateAdminUserRequest> created = [];
  final List<(String, UpdateAdminUserRequest)> updates = [];
  final List<String> deleted = [];

  /// Conta devolvida pelo 201 e pelo PATCH.
  AdminUser? savedUser;

  @override
  Future<AdminUserPage> list({
    String search = '',
    int page = 1,
    int pageSize = 100,
  }) async {
    listCalls++;
    lastSearch = search;
    lastPageSize = pageSize;
    await listGate?.future;
    final crash = listCrash;
    if (crash != null) throw crash;
    final failure = listFailure;
    if (failure != null) throw AdminUsersFailure(failure);
    return this.page;
  }

  @override
  Future<AdminUser> findById(String id) async {
    await detailGate?.future;
    final crash = detailCrash;
    if (crash != null) throw crash;
    final failure = detailFailure;
    if (failure != null) throw AdminUsersFailure(failure);
    return fromPage(id) ?? _fallback(id);
  }

  AdminUser? fromPage(String id) {
    for (final user in page.items) {
      if (user.id == id) return user;
    }
    return null;
  }

  AdminUser _fallback(String id) =>
      userAccount(id: id, name: 'Conta', email: 'conta@exemplo.com');

  @override
  Future<AdminUser> create(CreateAdminUserRequest request) async {
    created.add(request);
    await createGate?.future;
    final crash = createCrash;
    if (crash != null) throw crash;
    final failure = createFailure;
    if (failure != null) throw AdminUsersFailure(failure);
    return savedUser ??
        userAccount(
          id: 'novo-usuario',
          name: request.name,
          email: request.email,
          role: request.role,
        );
  }

  @override
  Future<AdminUser> update(String id, UpdateAdminUserRequest request) async {
    updates.add((id, request));
    await updateGate?.future;
    final failure = updateFailure;
    if (failure != null) throw AdminUsersFailure(failure);
    return savedUser ??
        userAccount(
          id: id,
          name: request.name,
          email: 'maria.souza@exemplo.com',
          role: request.role,
          active: request.active,
        );
  }

  @override
  Future<void> delete(String id) async {
    deleted.add(id);
    await deleteGate?.future;
    final failure = deleteFailure;
    if (failure != null) throw AdminUsersFailure(failure);
  }
}

class FakeAccessEventsGateway implements AccessEventsGateway {
  AdminAccessEventPage page = eventsPageOf([]);
  AccessEventsFailureReason? listFailure;
  Object? listCrash;
  Completer<void>? listGate;

  int listCalls = 0;
  AccessDecision? lastDecision;
  int lastPageSize = 0;

  @override
  Future<AdminAccessEventPage> list({
    AccessDecision? decision,
    int page = 1,
    int pageSize = 100,
  }) async {
    listCalls++;
    lastDecision = decision;
    lastPageSize = pageSize;
    await listGate?.future;
    final crash = listCrash;
    if (crash != null) throw crash;
    final failure = listFailure;
    if (failure != null) throw AccessEventsFailure(failure);
    return this.page;
  }
}
