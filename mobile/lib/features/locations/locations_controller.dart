import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session_controller.dart';
import 'http_location_gateway.dart';
import 'location_contract.dart';

/// Locais ativos do condomínio. A lista é curta e não tem paginação no
/// design: a tela pede uma única página de 100.
final locationsProvider =
    AsyncNotifierProvider<LocationsController, LocationPage>(
      LocationsController.new,
    );

class LocationsController extends AsyncNotifier<LocationPage> {
  @override
  Future<LocationPage> build() async {
    // Trocar de conta zera a lista: o dado de um usuário não aparece no outro.
    if (ref.watch(currentSessionProvider) == null) {
      return const LocationPage(items: [], page: 1, pageSize: 0, total: 0);
    }
    return _fetch();
  }

  Future<LocationPage> _fetch() =>
      ref.read(locationGatewayProvider).listActive();

  /// Pull-to-refresh e "Tentar novamente" mantêm a lista atual na tela
  /// enquanto buscam de novo.
  Future<void> refresh() async {
    state = await AsyncValue.guard(_fetch);
  }
}
