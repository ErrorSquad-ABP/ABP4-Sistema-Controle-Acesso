import 'dart:async';

import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/profile/http_profile_gateway.dart';

import '../auth/fakes.dart';

/// `PATCH /me` simulado; registra o nome enviado e pode falhar.
class FakeProfileGateway implements ProfileGateway {
  FakeProfileGateway({this.failure});

  AuthFailureReason? failure;

  /// Quando definido, o PATCH só responde ao completar o completer.
  Completer<void>? gate;

  final List<String> names = [];

  @override
  Future<AuthUser> updateName(String name) async {
    names.add(name);
    await gate?.future;
    if (failure != null) throw AuthFailure(failure!);
    return AuthUser(
      id: maria.id,
      name: name,
      email: maria.email,
      role: maria.role,
    );
  }
}
