import 'package:dapri_bot/date_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 9, 29);

  test('parses short day name with time range', () {
    final d = parseDatumprikkerDate('ma 12 okt 10:00 - 11:30', now: now)!;
    expect(d.start, DateTime(2026, 10, 12, 10));
    expect(d.end, DateTime(2026, 10, 12, 11, 30));
    expect(d.allDay, isFalse);
  });

  test('parses full names, explicit year and single time', () {
    final d = parseDatumprikkerDate('Maandag 12 januari 2027 14:00', now: now)!;
    expect(d.start, DateTime(2027, 1, 12, 14));
    expect(d.end, DateTime(2027, 1, 12, 15));
  });

  test('handles text split over lines and dotted times', () {
    final d = parseDatumprikkerDate('vr 2 okt\n19.30 - 22.00', now: now)!;
    expect(d.start, DateTime(2026, 10, 2, 19, 30));
    expect(d.end, DateTime(2026, 10, 2, 22));
  });

  test('date without time is a whole day', () {
    final d = parseDatumprikkerDate('za 3 okt', now: now)!;
    expect(d.allDay, isTrue);
    expect(d.start, DateTime(2026, 10, 3));
    expect(d.end, DateTime(2026, 10, 4));
  });

  test('month in the past without year means next year', () {
    final d = parseDatumprikkerDate('di 12 jan 20:00', now: now)!;
    expect(d.start.year, 2027);
  });

  test('recent date in the same year stays this year', () {
    final d = parseDatumprikkerDate('ma 21 sep 20:00', now: now)!;
    expect(d.start.year, 2026);
  });

  test('time range past midnight ends the next day', () {
    final d = parseDatumprikkerDate('za 10 okt 22:00 - 01:00', now: now)!;
    expect(d.end, DateTime(2026, 10, 11, 1));
  });

  test('returns null for unrecognizable text', () {
    expect(parseDatumprikkerDate('binnenkort', now: now), isNull);
  });
}
