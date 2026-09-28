import 'package:device_calendar_plus/device_calendar_plus.dart';

import 'settings.dart';

/// Calendars that are excluded on first use because they rarely mean you're
/// actually busy.
final _defaultExcluded = RegExp(
  r'verjaardag|birthday|feestdag|holiday|contacts|contactpersonen|week numbers|weeknummers',
  caseSensitive: false,
);

class CalendarService {
  CalendarService(this._settings);

  final Settings _settings;
  final _plugin = DeviceCalendar.instance;

  Future<bool> hasPermission() async =>
      await _plugin.hasPermissions() == CalendarPermissionStatus.granted;

  Future<bool> requestPermission() async =>
      await _plugin.requestPermissions() == CalendarPermissionStatus.granted;

  Future<void> openAppSettings() => _plugin.openAppSettings();

  Future<List<Calendar>> calendars() async {
    final calendars = (await _plugin.listCalendars()).where((c) => !c.hidden).toList()
      ..sort((a, b) => (a.accountName ?? '').compareTo(b.accountName ?? ''));
    if (_settings.excludedCalendarIds == null) {
      await _settings.setExcludedCalendarIds({
        for (final c in calendars)
          if (_defaultExcluded.hasMatch(c.name)) c.id,
      });
    }
    return calendars;
  }

  /// Events in the included calendars between [from] and [to].
  Future<List<Event>> events(DateTime from, DateTime to) async {
    final excluded = _settings.excludedCalendarIds ?? {};
    final ids = [
      for (final c in await calendars())
        if (!excluded.contains(c.id)) c.id,
    ];
    if (ids.isEmpty) return [];
    return _plugin.listEvents(from, to, calendarIds: ids);
  }
}
