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

/// Perfis do contrato v1 (`Role`).
enum UserRole {
  admin('ADMIN', 'Administrador'),
  resident('RESIDENT', 'Condômino'),
  visitor('VISITOR', 'Visitante');

  const UserRole(this.code, this.label);

  final String code;
  final String label;

  static UserRole fromCode(Object? code) => values.firstWhere(
    (role) => role.code == code,
    orElse: () => throw FormatException('Perfil desconhecido: $code'),
  );
}

/// Recorte do `User` do contrato que o app usa.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
    role: UserRole.fromCode(json['role']),
  );

  final String id;
  final String name;
  final String email;
  final UserRole role;

  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.code,
  };
}

/// Sessão local: JWT do `LoginResponse`, quando ele vence e quem está logado.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresAt,
    required this.user,
  });

  /// Folga para não usar um token que vence no meio da requisição.
  static const Duration expirySkew = Duration(seconds: 30);

  /// Converte o `LoginResponse` em sessão, contando a validade a partir de
  /// [now] (relógio do aparelho no momento da resposta).
  factory AuthSession.fromLoginResponse(
    Map<String, dynamic> json, {
    required DateTime now,
  }) {
    final token = json['accessToken'];
    final expiresIn = json['expiresIn'];
    if (json['tokenType'] != 'Bearer' ||
        token is! String ||
        token.isEmpty ||
        expiresIn is! int ||
        expiresIn < 1) {
      throw const FormatException('LoginResponse fora do contrato');
    }
    return AuthSession(
      accessToken: token,
      expiresAt: now.toUtc().add(Duration(seconds: expiresIn)),
      user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
    );
  }

  factory AuthSession.fromJson(Map<String, dynamic> json) => AuthSession(
    accessToken: json['accessToken'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String).toUtc(),
    user: AuthUser.fromJson(json['user'] as Map<String, dynamic>),
  );

  final String accessToken;
  final DateTime expiresAt;
  final AuthUser user;

  bool isExpiredAt(DateTime now) =>
      !now.toUtc().isBefore(expiresAt.subtract(expirySkew));

  AuthSession withUser(AuthUser user) =>
      AuthSession(accessToken: accessToken, expiresAt: expiresAt, user: user);

  Map<String, Object> toJson() => {
    'accessToken': accessToken,
    'expiresAt': expiresAt.toUtc().toIso8601String(),
    'user': user.toJson(),
  };
}

enum AuthFailureReason {
  /// 401: credencial inválida, usuário desativado ou token vencido.
  unauthorized,

  /// 400: entrada recusada pelo contrato.
  invalidRequest,

  /// 429: limite de tentativas.
  tooManyRequests,

  /// 503 ou 5xx: backend ou banco fora do ar.
  unavailable,

  /// Sem resposta: sem rede, DNS ou tempo esgotado.
  network,

  /// Resposta fora do contrato.
  unexpected,
}

class AuthFailure implements Exception {
  const AuthFailure(this.reason);

  final AuthFailureReason reason;

  @override
  String toString() => 'AuthFailure(${reason.name})';
}

/// `POST /auth/login` e `GET /auth/me` do contrato v1 (US-14).
abstract interface class AuthGateway {
  Future<AuthSession> login(LoginRequest request);

  Future<AuthUser> currentUser(String accessToken);
}
