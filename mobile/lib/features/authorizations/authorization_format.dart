/// Textos derivados que a lista mostra; separados da página para testar sem
/// widget tree.
library;

String _twoDigits(int value) => value.toString().padLeft(2, '0');

/// "3 de 5 usos restantes", igual na lista e no detalhe.
String remainingUsesLabel({required int remaining, required int max}) =>
    '$remaining de $max usos restantes';

String _dayLabel(DateTime day, DateTime now, {bool forceYear = false}) {
  final local = day.toLocal();
  final today = now.toLocal();
  if (local.year == today.year &&
      local.month == today.month &&
      local.day == today.day) {
    return 'Hoje';
  }
  final date = '${_twoDigits(local.day)}/${_twoDigits(local.month)}';
  return !forceYear && local.year == today.year
      ? date
      : '$date/${local.year}';
}

/// Janela da autorização no fuso do aparelho: `Hoje · 14:00–18:00`.
///
/// Quando o fim cai em outro dia, a data final entra no texto: uma janela que
/// vira a noite não pode parecer terminar antes de começar.
String authorizationWindowLabel({
  required DateTime startsAt,
  required DateTime endsAt,
  required DateTime now,
}) {
  final start = startsAt.toLocal();
  final end = endsAt.toLocal();
  final startTime = '${_twoDigits(start.hour)}:${_twoDigits(start.minute)}';
  final endTime = '${_twoDigits(end.hour)}:${_twoDigits(end.minute)}';
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${_dayLabel(start, now)} · $startTime–$endTime';
  }
  // O ano do fim também aparece quando muda em relação ao início.
  final endDay = _dayLabel(end, now, forceYear: end.year != start.year);
  return '${_dayLabel(start, now)} $startTime – $endDay $endTime';
}
