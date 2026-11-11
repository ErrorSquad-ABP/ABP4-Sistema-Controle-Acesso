/// Textos derivados que a lista mostra; separados da página para testar sem
/// widget tree.
library;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

String _dayLabel(DateTime day, DateTime now) {
  final local = day.toLocal();
  final today = now.toLocal();
  if (local.year == today.year &&
      local.month == today.month &&
      local.day == today.day) {
    return 'Hoje';
  }
  final date = '${_twoDigits(local.day)}/${_twoDigits(local.month)}';
  return local.year == today.year ? date : '$date/${local.year}';
}

/// Janela da autorização no fuso do aparelho: `Hoje · 14:00–18:00`.
String authorizationWindowLabel({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final start = startsAt.toLocal();
  final end = endsAt.toLocal();
  final startTime = '${_twoDigits(start.hour)}:${_twoDigits(start.minute)}';
  final endTime = '${_twoDigits(end.hour)}:${_twoDigits(end.minute)}';
  return '${_dayLabel(start, now)} · $startTime–$endTime';
}
