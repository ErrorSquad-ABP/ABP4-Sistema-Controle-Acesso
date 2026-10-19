import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Espelha LoginRequest da US-06. Não aplicar regras de criação de senha aqui.
abstract final class LoginValidation {
  static String? email(String? value) {
    final email = value ?? '';
    if (email.isEmpty) return 'Informe seu e-mail.';
    // Mesmo formato padrão de z.email(), incluindo a restrição a pontos duplos.
    final format = RegExp(
      r"^(?!\.)(?!.*\.\.)([A-Za-z0-9_'+\-\.]*)[A-Za-z0-9_+\-]@([A-Za-z0-9][A-Za-z0-9\-]*\.)+[A-Za-z]{2,}$",
    );
    if (email.length > 254 || !format.hasMatch(email)) {
      return 'Informe um e-mail válido (até 254 caracteres).';
    }
    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) return 'Informe sua senha.';
    if (value.length > 72) return 'A senha deve ter até 72 caracteres.';
    return null;
  }
}

class LoginRequest {
  LoginRequest({required String email, required this.password})
    : email = email.toLowerCase();

  final String email;
  final String password;

  Map<String, String> toJson() => {'email': email, 'password': password};
}

abstract interface class LoginGateway {
  Future<void> login(LoginRequest request);
}

/// Substituir pelo adaptador HTTP de POST /api/v1/auth/login na US-14.
/// O stub atual não autentica, não emite JWT e não cria sessão local.
class StubLoginGateway implements LoginGateway {
  @override
  Future<void> login(LoginRequest request) async {
    await Future<void>.delayed(const Duration(milliseconds: 600));
    throw const LoginUnavailable();
  }
}

class LoginUnavailable implements Exception {
  const LoginUnavailable();
  static const int statusCode = 501;
  static const String code = 'NOT_IMPLEMENTED';
}

final loginGatewayProvider = Provider<LoginGateway>(
  (ref) => StubLoginGateway(),
);
