import 'package:device_calendar_plus/device_calendar_plus.dart';

import 'models.dart';

/// Suggests an answer for [option] based on the user's calendar [events].
///
/// - Events marked "free" and cancelled events never block.
/// - All-day events only block when marked busy (e.g. a holiday), since
///   Google Calendar marks birthdays and most all-day events as free.
/// - Tentative events suggest "maybe" when the poll supports it.
/// - For a whole-day option, busy timed events on that day suggest "maybe":
///   you might still be able to make it.
Suggestion suggestAnswer(PollOption option, List<Event> events) {
  if (!option.parsed) return Suggestion(Answer.skip, const []);

  final conflicts = events.where((e) => _blocks(e) && _overlaps(option, e)).toList()
    ..sort((a, b) => a.startDate.compareTo(b.startDate));

  final hardConflicts = conflicts.where((e) => !_tentative(e)).toList();
  final canMaybe = option.answerClasses.containsKey(Answer.maybe);

  Answer answer;
  if (option.allDay) {
    if (hardConflicts.any((e) => e.isAllDay)) {
      answer = Answer.no;
    } else if (conflicts.isNotEmpty) {
      answer = canMaybe ? Answer.maybe : Answer.yes;
    } else {
      answer = Answer.yes;
    }
  } else if (hardConflicts.isNotEmpty) {
    answer = Answer.no;
  } else if (conflicts.isNotEmpty) {
    answer = canMaybe ? Answer.maybe : Answer.no;
  } else {
    answer = Answer.yes;
  }

  if (!option.answerClasses.containsKey(answer)) answer = Answer.skip;
  return Suggestion(answer, conflicts);
}

bool _blocks(Event e) {
  if (e.status == EventStatus.canceled) return false;
  if (e.availability == EventAvailability.free) return false;
  if (e.isAllDay) {
    return e.availability == EventAvailability.busy ||
        e.availability == EventAvailability.unavailable;
  }
  return true;
}

bool _tentative(Event e) =>
    e.availability == EventAvailability.tentative || e.status == EventStatus.tentative;

bool _overlaps(PollOption option, Event e) {
  final DateTime eventStart;
  final DateTime eventEnd;
  if (e.isAllDay) {
    // All-day events are floating dates: compare by calendar day.
    eventStart = DateTime(e.startDate.year, e.startDate.month, e.startDate.day);
    final endDay = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
    eventEnd = endDay.isAfter(eventStart) ? endDay : eventStart.add(const Duration(days: 1));
  } else {
    eventStart = e.startDate;
    eventEnd = e.endDate;
  }
  return option.start!.isBefore(eventEnd) && option.end!.isAfter(eventStart);
}
