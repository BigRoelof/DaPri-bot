import 'package:dapri_bot/availability.dart';
import 'package:dapri_bot/models.dart';
import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter_test/flutter_test.dart';

const _yesNoMaybe = {Answer.yes: 'yes', Answer.no: 'no', Answer.maybe: 'maybe'};
const _yesNo = {Answer.yes: 'yes', Answer.no: 'no'};

PollOption _option(DateTime start, DateTime end,
        {bool allDay = false, Map<Answer, String> answers = _yesNoMaybe}) =>
    PollOption(
        index: 0, text: '', answerClasses: answers, start: start, end: end, allDay: allDay);

Event _event(
  DateTime start,
  DateTime end, {
  bool allDay = false,
  EventAvailability availability = EventAvailability.busy,
  EventStatus status = EventStatus.confirmed,
}) =>
    Event(
      eventId: 'e',
      instanceId: 'e',
      calendarId: 'c',
      title: 'Afspraak',
      startDate: start,
      endDate: end,
      isAllDay: allDay,
      availability: availability,
      status: status,
      isRecurring: false,
    );

void main() {
  final evening = _option(DateTime(2026, 10, 12, 19), DateTime(2026, 10, 12, 22));

  test('no events means yes', () {
    expect(suggestAnswer(evening, []).answer, Answer.yes);
  });

  test('overlapping busy event means no', () {
    final s = suggestAnswer(
        evening, [_event(DateTime(2026, 10, 12, 18), DateTime(2026, 10, 12, 20))]);
    expect(s.answer, Answer.no);
    expect(s.conflicts, hasLength(1));
  });

  test('adjacent event does not conflict', () {
    final s = suggestAnswer(
        evening, [_event(DateTime(2026, 10, 12, 17), DateTime(2026, 10, 12, 19))]);
    expect(s.answer, Answer.yes);
  });

  test('free and cancelled events are ignored', () {
    final s = suggestAnswer(evening, [
      _event(DateTime(2026, 10, 12, 19), DateTime(2026, 10, 12, 20),
          availability: EventAvailability.free),
      _event(DateTime(2026, 10, 12, 19), DateTime(2026, 10, 12, 20),
          status: EventStatus.canceled),
    ]);
    expect(s.answer, Answer.yes);
  });

  test('tentative event means maybe, or no without a maybe option', () {
    final tentative = [
      _event(DateTime(2026, 10, 12, 20), DateTime(2026, 10, 12, 21),
          availability: EventAvailability.tentative),
    ];
    expect(suggestAnswer(evening, tentative).answer, Answer.maybe);
    final yesNo = _option(evening.start!, evening.end!, answers: _yesNo);
    expect(suggestAnswer(yesNo, tentative).answer, Answer.no);
  });

  test('all-day event only blocks when marked busy', () {
    final day = [DateTime(2026, 10, 12), DateTime(2026, 10, 13)];
    expect(
      suggestAnswer(evening, [
        _event(day[0], day[1], allDay: true, availability: EventAvailability.free),
      ]).answer,
      Answer.yes,
    );
    expect(
      suggestAnswer(evening, [_event(day[0], day[1], allDay: true)]).answer,
      Answer.no,
    );
  });

  test('whole-day option with a timed event means maybe', () {
    final wholeDay =
        _option(DateTime(2026, 10, 12), DateTime(2026, 10, 13), allDay: true);
    final s = suggestAnswer(
        wholeDay, [_event(DateTime(2026, 10, 12, 9), DateTime(2026, 10, 12, 10))]);
    expect(s.answer, Answer.maybe);
  });

  test('unparsed option is skipped', () {
    final unparsed = PollOption(index: 0, text: '?', answerClasses: _yesNo);
    expect(suggestAnswer(unparsed, []).answer, Answer.skip);
  });
}
