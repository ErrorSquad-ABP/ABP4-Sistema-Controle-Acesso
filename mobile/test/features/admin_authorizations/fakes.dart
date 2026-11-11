import 'dart:async';

import 'package:controle_acesso/features/admin_authorizations/admin_authorization_contract.dart';
import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/authorizations/authorization_contract.dart';

import '../authorizations/fakes.dart';

/// Pessoa ativa do diretório, como `GET /users` devolve.
AdminUser directoryUser({
  String id = '7f8c1f5e-6c1a-4a8e-9a43-2d4b9f1c0a11',
  String name = 'Maria Souza',
  String email = 'maria.souza@exemplo.com',
  UserRole role = UserRole.visitor,
  bool active = true,
}) => AdminUser(id: id, name: name, email: email, role: role, active: active);

AdminUserPage userPageOf(List<AdminUser> items) =>
    AdminUserPage(items: items, page: 1, pageSize: 100, total: items.length);

/// Responde sem rede. Os `gates` seguram a resposta para o teste ver o
/// carregando, o criando e o cancelando.
class FakeAdminAuthorizationGateway implements AdminAuthorizationGateway {
  AuthorizationPage page = pageOf([]);

  AdminFailureReason? listFailure;
  AdminFailureReason? createFailure;
  AdminFailureReason? cancelFailure;

  /// Erro fora do contrato, para checar que a tela não quebra.
  Object? listCrash;
  Object? createCrash;

  Completer<void>? listGate;
  Completer<void>? createGate;
  Completer<void>? cancelGate;

  int listCalls = 0;
  AuthorizationStatus? lastStatus;
  final List<CreateAuthorizationRequest> created = [];
  final List<({String id, String reason})> canceled = [];

  /// Agendamento devolvido pelo 201; por padrão, uma autorização de teste.
  Authorization? createdAuthorization;

  @override
  Future<AuthorizationPage> list({
    int page = 1,
    int pageSize = 100,
    AuthorizationStatus? status,
  }) async {
    listCalls++;
    lastStatus = status;
    await listGate?.future;
    final crash = listCrash;
    if (crash != null) throw crash;
    final failure = listFailure;
    if (failure != null) throw AdminFailure(failure);
    return this.page;
  }

  @override
  Future<Authorization> create(CreateAuthorizationRequest request) async {
    created.add(request);
    await createGate?.future;
    final crash = createCrash;
    if (crash != null) throw crash;
    final failure = createFailure;
    if (failure != null) throw AdminFailure(failure);
    return createdAuthorization ?? authorization();
  }

  @override
  Future<Authorization> cancel(String id, String reason) async {
    canceled.add((id: id, reason: reason));
    await cancelGate?.future;
    final failure = cancelFailure;
    if (failure != null) throw AdminFailure(failure);
    return authorization(status: AuthorizationStatus.canceled);
  }
}

class FakeAdminUserGateway implements AdminUserGateway {
  AdminUserPage page = userPageOf([directoryUser()]);

  AdminFailureReason? failure;
  Object? crash;
  Completer<void>? gate;

  int calls = 0;
  String? lastSearch;
  bool? lastActive;

  @override
  Future<AdminUserPage> list({
    String? search,
    int page = 1,
    int pageSize = 100,
    bool? active,
  }) async {
    calls++;
    lastSearch = search;
    lastActive = active;
    await gate?.future;
    final crash = this.crash;
    if (crash != null) throw crash;
    final failure = this.failure;
    if (failure != null) throw AdminFailure(failure);
    return this.page;
  }
}
