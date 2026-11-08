/// Date courte française : `08/11/26`.
String formatFrenchShortDate(String? raw) {
  final date = _parseDate(raw);
  if (date == null) {
    final text = raw?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    return text;
  }
  return _dateLabel(date);
}

/// Date et heure : `08/11/26 à 14:30`.
/// [time] est utilisé quand la date n’en contient pas (`reservationHeure`).
String formatFrenchDateTime(String? raw, {String? time}) {
  final date = _parseDate(raw);
  final clock = _clockLabel(time) ?? (date == null ? null : _clockFromDate(raw, date));
  if (date == null) {
    if (clock != null) return clock;
    final text = raw?.trim() ?? '';
    if (text.isEmpty || text.toLowerCase() == 'null') return '—';
    return text;
  }
  final label = _dateLabel(date);
  if (clock == null) return label;
  return '$label à $clock';
}

/// Séjour : `Du 08/11/26 à 14:00 au 10/11/26`.
String formatFrenchStay(String? start, String? end, {String? time}) {
  final arrival = formatFrenchDateTime(start, time: time);
  final departure = formatFrenchDateTime(end);
  if (arrival == '—' && departure == '—') return '—';
  if (departure == '—') return 'Du $arrival';
  if (arrival == '—') return 'Au $departure';
  return 'Du $arrival au $departure';
}

String _dateLabel(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  final year = (date.year % 100).toString().padLeft(2, '0');
  return '$day/$month/$year';
}

DateTime? _parseDate(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  var date = DateTime.tryParse(text);
  if (date == null && text.length >= 10) {
    date = DateTime.tryParse(text.substring(0, 10));
  }
  if (date != null) return date;
  final match = RegExp(r'(\d{1,2})[\/\-.](\d{1,2})[\/\-.](\d{2,4})').firstMatch(text);
  if (match == null) return null;
  var year = int.parse(match.group(3)!);
  if (year < 100) year += 2000;
  return DateTime(year, int.parse(match.group(2)!), int.parse(match.group(1)!));
}

String? _clockFromDate(String? raw, DateTime date) {
  final text = raw?.trim() ?? '';
  final hasClock = text.contains('T') || RegExp(r'\d{1,2}:\d{2}').hasMatch(text);
  if (!hasClock) return null;
  if (date.hour == 0 && date.minute == 0 && date.second == 0) return null;
  return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

String? _clockLabel(String? raw) {
  final text = raw?.trim() ?? '';
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  final match = RegExp(r'(\d{1,2})\s*[:hH]\s*(\d{2})').firstMatch(text);
  if (match == null) return null;
  final hour = int.tryParse(match.group(1)!);
  final minute = int.tryParse(match.group(2)!);
  if (hour == null || minute == null) return null;
  if (hour == 0 && minute == 0 && !text.contains(':') && !text.toLowerCase().contains('h')) {
    return null;
  }
  return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}
