/// Recorte de `GET/POST /locations` (US-39) que as telas usam.
///
/// A API só lista locais ativos, em ordem alfabética; o app não reordena nem
/// pagina (o design não tem paginação) e pede a primeira página inteira.
class Location {
  const Location({
    required this.id,
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    required this.isActive,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final description = json['description'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final radiusMeters = json['radiusMeters'];
    final isActive = json['isActive'];
    if (id is! String ||
        id.trim().isEmpty ||
        name is! String ||
        name.trim().isEmpty ||
        (description != null && description is! String) ||
        latitude is! num ||
        latitude < -90 ||
        latitude > 90 ||
        longitude is! num ||
        longitude < -180 ||
        longitude > 180 ||
        radiusMeters is! int ||
        radiusMeters < 1 ||
        radiusMeters > 100 ||
        isActive is! bool) {
      throw const FormatException('Local fora do contrato');
    }
    final trimmed = (description as String?)?.trim();
    return Location(
      id: id.trim(),
      name: name.trim(),
      description: trimmed == null || trimmed.isEmpty ? null : trimmed,
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
      radiusMeters: radiusMeters,
      isActive: isActive,
    );
  }

  final String id;
  final String name;
  final String? description;
  final double latitude;
  final double longitude;
  final int radiusMeters;
  final bool isActive;
}

/// Envelope paginado `{ items, page, pageSize, total }`.
class LocationPage {
  const LocationPage({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.total,
  });

  factory LocationPage.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final page = json['page'];
    final pageSize = json['pageSize'];
    final total = json['total'];
    if (items is! List || page is! int || pageSize is! int || total is! int) {
      throw const FormatException('LocationPage fora do contrato');
    }
    return LocationPage(
      items: [
        for (final item in items)
          if (item is Map<String, dynamic>)
            Location.fromJson(item)
          else
            throw const FormatException('Item da pagina fora do contrato'),
      ],
      page: page,
      pageSize: pageSize,
      total: total,
    );
  }

  final List<Location> items;
  final int page;
  final int pageSize;
  final int total;
}

/// Corpo de `POST /locations`. Os limites são os mesmos do contrato da API
/// (`CreateLocationRequest`): a validação local evita um 400 previsível.
class CreateLocationRequest {
  CreateLocationRequest({
    required String name,
    required String description,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  }) : name = name.trim(),
       description = description.trim();

  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final int radiusMeters;

  Map<String, Object> toJson() => {
    'name': name,
    if (description.isNotEmpty) 'description': description,
    'latitude': latitude,
    'longitude': longitude,
    'radiusMeters': radiusMeters,
  };
}

/// Validação local espelhando o zod do backend: nome 2..120, descrição até
/// 200, latitude -90..90, longitude -180..180 e raio 1..100 (DT-23).
abstract final class LocationValidation {
  static const int maxDescriptionLength = 200;

  static String? name(String? value) {
    final name = (value ?? '').trim();
    if (name.isEmpty) return 'Informe o nome do local.';
    if (name.length < 2) return 'O nome deve ter pelo menos 2 caracteres.';
    if (name.length > 120) return 'O nome deve ter até 120 caracteres.';
    return null;
  }

  static String? description(String? value) {
    final description = (value ?? '').trim();
    if (description.length > maxDescriptionLength) {
      return 'O endereço deve ter até $maxDescriptionLength caracteres.';
    }
    return null;
  }

  static String? latitude(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Informe a latitude.';
    final parsed = parseDecimal(raw);
    if (parsed == null) return 'Informe uma latitude válida.';
    if (parsed < -90 || parsed > 90) {
      return 'A latitude deve ficar entre -90 e 90.';
    }
    return null;
  }

  static String? longitude(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Informe a longitude.';
    final parsed = parseDecimal(raw);
    if (parsed == null) return 'Informe uma longitude válida.';
    if (parsed < -180 || parsed > 180) {
      return 'A longitude deve ficar entre -180 e 180.';
    }
    return null;
  }

  static String? radius(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) return 'Informe o raio em metros.';
    final parsed = int.tryParse(raw);
    if (parsed == null) return 'Informe o raio em metros inteiros.';
    if (parsed < 1 || parsed > 100) {
      return 'O raio deve ficar entre 1 e 100 metros.';
    }
    return null;
  }

  /// Teclado numérico em pt-BR manda vírgula; o campo aceita os dois.
  static double? parseDecimal(String? value) =>
      double.tryParse((value ?? '').trim().replaceAll(',', '.'));
}

enum LocationFailureReason {
  /// 401: token recusado; o cliente autenticado encerra a sessão.
  unauthorized,

  /// 403: perfil sem permissão para cadastrar.
  forbidden,

  /// 400: o contrato recusou os dados enviados.
  invalidRequest,

  /// 5xx ou 429: backend fora, sem banco ou pedindo calma.
  unavailable,

  /// Sem resposta: sem rede ou DNS.
  network,

  /// O servidor não respondeu dentro do prazo.
  timeout,

  /// Resposta fora do contrato.
  unexpected,
}

class LocationFailure implements Exception {
  const LocationFailure(this.reason);

  final LocationFailureReason reason;

  @override
  String toString() => 'LocationFailure(${reason.name})';
}

abstract interface class LocationGateway {
  Future<LocationPage> listActive({int page, int pageSize});

  Future<Location> create(CreateLocationRequest request);
}
