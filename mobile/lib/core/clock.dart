import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Relógio injetável: prazos (ex.: validade da sessão) são contados a partir
/// dele, e os testes o fixam.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);
