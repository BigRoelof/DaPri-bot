import 'package:device_calendar_plus/device_calendar_plus.dart';

/// An answer that can be given to one date option of a poll.
enum Answer {
  yes('Ja'),
  maybe('Misschien'),
  no('Nee'),
  skip('Overslaan');

  const Answer(this.label);
  final String label;
}

/// One date option as read from the Datumprikker page.
class PollOption {
  PollOption({
    required this.index,
    required this.text,
    required this.answerClasses,
    this.start,
    this.end,
    this.allDay = false,
  });

  /// Position of the `.eventdate` row on the page, used to click it later.
  final int index;

  /// The raw date text shown by Datumprikker, e.g. "ma 12 mei 14:00 - 15:00".
  final String text;

  /// CSS class of the `<li>` to click for each answer this poll supports.
  final Map<Answer, String> answerClasses;

  /// Parsed start and end; null when the text could not be parsed.
  final DateTime? start;
  final DateTime? end;

  /// True when the option is a whole day without a time.
  final bool allDay;

  bool get parsed => start != null && end != null;

  Set<Answer> get supportedAnswers => {...answerClasses.keys, Answer.skip};
}

/// The suggested answer for an option together with the reason for it.
class Suggestion {
  Suggestion(this.answer, this.conflicts);

  final Answer answer;

  /// Calendar events that overlap the option.
  final List<Event> conflicts;
}
