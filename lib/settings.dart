import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User settings: the details filled in on Datumprikker and which calendars
/// count towards availability.
class Settings extends ChangeNotifier {
  Settings._(this._prefs);

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  final SharedPreferences _prefs;

  String get name => _prefs.getString('name') ?? '';
  String get email => _prefs.getString('email') ?? '';

  /// Null until the user (or the first-run default) picked calendars.
  Set<String>? get excludedCalendarIds =>
      _prefs.getStringList('excludedCalendars')?.toSet();

  bool get isComplete => name.trim().isNotEmpty;

  Future<void> setDetails({required String name, required String email}) async {
    await _prefs.setString('name', name.trim());
    await _prefs.setString('email', email.trim());
    notifyListeners();
  }

  Future<void> setExcludedCalendarIds(Set<String> ids) async {
    await _prefs.setStringList('excludedCalendars', ids.toList());
    notifyListeners();
  }
}
