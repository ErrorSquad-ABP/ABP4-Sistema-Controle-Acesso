import 'dart:async';

import 'package:controle_acesso/features/auth/auth_contract.dart';
import 'package:controle_acesso/features/locations/location_contract.dart';

/// Administrador da sessão: o perfil que a API aceita em `POST /locations`.
const adminUser = AuthUser(
  id: '0d6a6f7e-1f2b-4c3d-8e4f-5a6b7c8d9e0f',
  name: 'Ana Lima',
  email: 'ana.lima@exemplo.com',
  role: UserRole.admin,
);

Location location({
  String id = 'c1f2a3b4-1111-4222-8333-944455556666',
  String name = 'Edifício Aurora · Recepção',
  String? description = 'Av. Central, 1200',
  double latitude = -23.1857,
  double longitude = -45.8846,
  int radiusMeters = 100,
  bool isActive = true,
}) => Location(
  id: id,
  name: name,
  description: description,
  latitude: latitude,
  longitude: longitude,
  radiusMeters: radiusMeters,
  isActive: isActive,
);

LocationPage pageOf(List<Location> items) => LocationPage(
  items: items,
  page: 1,
  pageSize: 100,
  total: items.length,
);

/// Responde sem rede. Os `gate`s seguram a resposta para o teste ver o
/// carregando e o salvando.
class FakeLocationGateway implements LocationGateway {
  LocationPage page = pageOf([]);

  /// Páginas por número, para testar a paginação sob demanda.
  final Map<int, LocationPage> pages = {};

  LocationFailureReason? listFailure;
  LocationFailureReason? createFailure;

  /// Erro fora do contrato, para checar que a tela não quebra.
  Object? listCrash;
  Object? createCrash;

  Completer<void>? listGate;
  Completer<void>? createGate;

  int listCalls = 0;
  int lastPage = 0;
  int lastPageSize = 0;
  final List<CreateLocationRequest> created = [];

  /// Local devolvido pelo 201; por padrão, o mesmo corpo enviado.
  Location? createdLocation;

  @override
  Future<LocationPage> listActive({
    int page = 1,
    int pageSize = 100,
  }) async {
    listCalls++;
    lastPage = page;
    lastPageSize = pageSize;
    await listGate?.future;
    final crash = listCrash;
    if (crash != null) throw crash;
    final failure = listFailure;
    if (failure != null) throw LocationFailure(failure);
    return pages[page] ?? this.page;
  }

  @override
  Future<Location> create(CreateLocationRequest request) async {
    created.add(request);
    await createGate?.future;
    final crash = createCrash;
    if (crash != null) throw crash;
    final failure = createFailure;
    if (failure != null) throw LocationFailure(failure);
    return createdLocation ??
        location(
          name: request.name,
          description: request.description.isEmpty
              ? null
              : request.description,
          latitude: request.latitude,
          longitude: request.longitude,
          radiusMeters: request.radiusMeters,
        );
  }
}
