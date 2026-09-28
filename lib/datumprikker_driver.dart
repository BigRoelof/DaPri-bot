import 'dart:async';
import 'dart:convert';

import 'package:webview_flutter/webview_flutter.dart';

import 'date_parser.dart';
import 'models.dart';

/// Datumprikker's selectors are known to work for the desktop layout (see the
/// original Selenium script), so the page is loaded as a desktop browser.
const _desktopUserAgent =
    'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) '
    'Chrome/130.0.0.0 Safari/537.36';

class DatumprikkerException implements Exception {
  DatumprikkerException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Drives a Datumprikker poll inside a WebView, like the Selenium script did:
/// open the poll, read the date options, click the answers and fill in the
/// user's details. It stops at the overview page so the user submits.
class DatumprikkerDriver {
  DatumprikkerDriver() {
    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(_desktopUserAgent);
  }

  final controller = WebViewController();

  static final linkPattern =
      RegExp(r'https?://(?:www\.)?datumprikker\.nl/\S+', caseSensitive: false);

  /// Extracts a Datumprikker link from shared text, or null.
  static Uri? findLink(String text) {
    final match = linkPattern.firstMatch(text);
    return match == null ? null : Uri.tryParse(match[0]!);
  }

  /// Opens the poll and returns its date options.
  Future<List<PollOption>> open(Uri url, {void Function(String)? onStep}) async {
    onStep?.call('Datumprikker openen…');
    // `hl=nl` makes the page Dutch, so the date texts can be parsed.
    await controller.loadRequest(
      url.replace(queryParameters: {...url.queryParameters, 'hl': 'nl'}),
    );

    onStep?.call('Cookiemelding wegklikken…');
    if (await _waitFor('#didomi-notice-agree-button', timeout: const Duration(seconds: 6))) {
      await _click('#didomi-notice-agree-button');
    }

    onStep?.call('Datums ophalen…');
    if (!await _waitFor('.eventdate', timeout: const Duration(seconds: 2))) {
      if (!await _waitFor('#nav_next')) {
        throw DatumprikkerException(
            'Dit lijkt geen Datumprikker-uitnodiging te zijn, of de pagina laadt niet.');
      }
      await _click('#nav_next');
      if (!await _waitFor('.eventdate')) {
        throw DatumprikkerException('Geen datums gevonden op de Datumprikker-pagina.');
      }
    }
    // Give the grid a moment to finish rendering all rows.
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final rows = await _eval('''
      Array.from(document.querySelectorAll('.eventdate')).map(row => ({
        text: (row.querySelector('.date') || row).innerText,
        classes: Array.from(row.querySelectorAll('li')).map(li => li.className),
      }))
    ''') as List;

    return [
      for (final (i, row) in rows.indexed)
        _toOption(i, (row['text'] as String).trim(), List<String>.from(row['classes'])),
    ];
  }

  PollOption _toOption(int index, String text, List<String> liClasses) {
    final answers = <Answer, String>{};
    for (final cls in liClasses) {
      final names = cls.split(RegExp(r'\s+'));
      if (names.contains('yes')) {
        answers[Answer.yes] ??= 'yes';
      } else if (names.contains('no')) {
        answers[Answer.no] ??= 'no';
      } else {
        final maybe = names.where(
            (n) => RegExp(r'maybe|question|ifneed|perhaps|misschien').hasMatch(n));
        if (maybe.isNotEmpty) answers[Answer.maybe] ??= maybe.first;
      }
    }
    final parsed = parseDatumprikkerDate(text);
    return PollOption(
      index: index,
      text: text.replaceAll(RegExp(r'\s+'), ' '),
      answerClasses: answers,
      start: parsed?.start,
      end: parsed?.end,
      allDay: parsed?.allDay ?? false,
    );
  }

  /// Clicks the chosen answers, fills in name and email and moves on to the
  /// overview page, where the user checks and submits.
  Future<void> fill(
    Map<PollOption, Answer> answers, {
    required String name,
    required String email,
    void Function(String)? onStep,
  }) async {
    onStep?.call('Beschikbaarheid aanklikken…');
    for (final MapEntry(key: option, value: answer) in answers.entries) {
      final cls = option.answerClasses[answer];
      if (cls == null) continue;
      await _eval('''
        (() => {
          const row = document.querySelectorAll('.eventdate')[${option.index}];
          const li = row && row.querySelector('li.${cls.replaceAll("'", '')}');
          if (li) li.click();
          return !!li;
        })()
      ''');
    }

    onStep?.call('Je gegevens invullen…');
    await _click('#nav_next');
    if (!await _waitFor('#eventname')) {
      throw DatumprikkerException('Het formulier voor je naam verscheen niet.');
    }
    await _setValue('#eventname', name);
    if (email.isNotEmpty) await _setValue('#eventemail', email);

    onStep?.call('Naar het overzicht…');
    await _click('#nav_next');
    await Future<void>.delayed(const Duration(seconds: 1));
  }

  Future<bool> _waitFor(String selector,
      {Duration timeout = const Duration(seconds: 15)}) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        if (await _eval('!!document.querySelector(${jsonEncode(selector)})') == true) {
          return true;
        }
      } catch (_) {
        // The page is navigating; try again.
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    return false;
  }

  Future<void> _click(String selector) => _eval('''
    (() => {
      const el = document.querySelector(${jsonEncode(selector)});
      if (el) el.click();
      return !!el;
    })()
  ''');

  /// Sets an input's value the way typing would, so the page notices it.
  Future<void> _setValue(String selector, String value) => _eval('''
    (() => {
      const el = document.querySelector(${jsonEncode(selector)});
      if (!el) return false;
      const setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
      setter.call(el, ${jsonEncode(value)});
      el.dispatchEvent(new Event('input', {bubbles: true}));
      el.dispatchEvent(new Event('change', {bubbles: true}));
      return true;
    })()
  ''');

  /// Runs [script] and returns its result, decoded from JSON.
  Future<Object?> _eval(String script) async {
    Object? result =
        await controller.runJavaScriptReturningResult('JSON.stringify($script)');
    // Platforms differ in whether the returned string is JSON-quoted once more.
    for (var i = 0; i < 2 && result is String; i++) {
      try {
        result = jsonDecode(result);
      } on FormatException {
        break;
      }
    }
    return result;
  }
}
