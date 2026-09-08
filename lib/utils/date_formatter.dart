/// Formateadores de fecha/hora de uso general, sin atarse a ninguna
/// funcionalidad concreta. Cualquier vista o controller del proyecto puede
/// importar este archivo en vez de reimplementar su propio formateador.
library;

String _monthShortName(int month) => switch (month) {
  1 => 'ene',
  2 => 'feb',
  3 => 'mar',
  4 => 'abr',
  5 => 'may',
  6 => 'jun',
  7 => 'jul',
  8 => 'ago',
  9 => 'sep',
  10 => 'oct',
  11 => 'nov',
  _ => 'dic',
};

String formatHourLabel(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final suffix = dateTime.hour >= 12 ? 'p. m.' : 'a. m.';
  return '$hour:$minute $suffix';
}

String formatDayMonthLabel(DateTime dateTime) {
  final month = _monthShortName(dateTime.month);
  return '${dateTime.day.toString().padLeft(2, '0')} $month';
}

String formatDateTimeLabel(DateTime dateTime) =>
    '${formatDayMonthLabel(dateTime)} · ${formatHourLabel(dateTime)}';

String formatDateRangeLabel(DateTime start, DateTime end) {
  final sameDay =
      start.year == end.year &&
      start.month == end.month &&
      start.day == end.day;
  if (sameDay) {
    return '${formatDayMonthLabel(start)} · ${formatHourLabel(start)} - ${formatHourLabel(end)}';
  }
  return '${formatDateTimeLabel(start)} → ${formatDateTimeLabel(end)}';
}
