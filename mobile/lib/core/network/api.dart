import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Endereço do backend. Troca no build/run com
/// `--dart-define=API_BASE_URL=http://10.0.2.2:3000` (emulador Android
/// apontando para o backend local).
abstract final class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://abp-4-sistema-controle-acesso.vercel.app',
  );

  /// Prazo de cada requisição; cobre a partida a frio da Vercel.
  static const Duration timeout = Duration(seconds: 20);
}

final apiBaseUrlProvider = Provider<String>((ref) => ApiConfig.baseUrl);

/// Cliente HTTP único do app, sobrescrito nos testes por `MockClient`.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});
