/// Parses the Dutch date texts that Datumprikker shows, such as
/// "ma 12 mei 10:00 - 11:00", "maandag 12 mei 2026 14:00" or "za 3 okt".
library;

const _months = {
  'jan': 1, 'januari': 1,
  'feb': 2, 'februari': 2,
  'mrt': 3, 'maart': 3,
  'apr': 4, 'april': 4,
  'mei': 5,
  'jun': 6, 'juni': 6,
  'jul': 7, 'juli': 7,
  'aug': 8, 'augustus': 8,
  'sep': 9, 'sept': 9, 'september': 9,
  'okt': 10, 'oktober': 10,
  'nov': 11, 'november': 11,
  'dec': 12, 'december': 12,
};

final _pattern = RegExp(
  r'(\d{1,2})\s+([a-z]+)\.?\s*(\d{4})?'
  r'(?:[^\d]*?(\d{1,2})[:.](\d{2})(?:\s*(?:-|–|tot)\s*(\d{1,2})[:.](\d{2}))?)?',
);

class ParsedDate {
  ParsedDate(this.start, this.end, {required this.allDay});

  final DateTime start;
  final DateTime end;
  final bool allDay;

  @override
  String toString() => 'ParsedDate($start - $end, allDay: $allDay)';
}

/// Returns null when [text] contains no recognizable date.
///
/// Without a year in the text, the date is placed in the current year, or in
/// the next year when that would put it more than a month in the past.
/// Without an end time the option is assumed to last one hour.
ParsedDate? parseDatumprikkerDate(String text, {DateTime? now}) {
  now ??= DateTime.now();
  final normalized = text.toLowerCase().replaceAll(RegExp(r'[\s,]+'), ' ');

  for (final m in _pattern.allMatches(normalized)) {
    final month = _months[m[2]];
    if (month == null) continue;
    final day = int.parse(m[1]!);

    var year = m[3] != null ? int.parse(m[3]!) : now.year;
    if (m[3] == null &&
        DateTime(year, month, day).isBefore(now.subtract(const Duration(days: 31)))) {
      year++;
    }

    if (m[4] == null) {
      final start = DateTime(year, month, day);
      return ParsedDate(start, DateTime(year, month, day + 1), allDay: true);
    }

    final start = DateTime(year, month, day, int.parse(m[4]!), int.parse(m[5]!));
    var end = m[6] != null
        ? DateTime(year, month, day, int.parse(m[6]!), int.parse(m[7]!))
        : start.add(const Duration(hours: 1));
    // "22:00 - 01:00" or "20:00 - 24:00" runs past midnight.
    if (!end.isAfter(start)) end = end.add(const Duration(days: 1));
    return ParsedDate(start, end, allDay: false);
  }
  return null;
}
