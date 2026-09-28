# DaPri

A Flutter app that fills in a [Datumprikker](https://datumprikker.nl/) poll based on the calendar on your phone. It is based on the Python/Selenium script [Datumprikker-Autofiller](https://github.com/evo439/Datumprikker-Autofiller).

## How it works

1. Share a Datumprikker link to **DaPri** (for example from WhatsApp), or paste it in the app.
2. DaPri opens the poll in a built-in browser, reads the date options, and compares them with your calendar.
3. You see a suggested **Yes / Maybe / No** for each date, with the events that conflict. Change any answer you disagree with.
4. Tap **Invullen op Datumprikker**. DaPri clicks your answers, fills in your name and email, and stops at the overview page. You check the result and submit it yourself.

### Suggestion rules

| Situation | Suggestion |
|---|---|
| Nothing in your calendar | Yes |
| Overlapping busy event | No |
| Overlapping tentative event | Maybe (No if the poll has no Maybe) |
| All-day event marked *busy* (e.g. a holiday) | No |
| All-day event marked *free* (birthdays, most all-day events) | ignored |
| Whole-day poll option with timed events that day | Maybe |
| Date text that could not be read | left open for you |

Calendars such as birthdays, holidays, and week numbers are excluded by default. You can choose which calendars count under **Instellingen**.

## Calendar access

DaPri reads the calendars that are synced to your phone: on Android through the Calendar Provider, so your Google Calendar works without a Google Cloud project or OAuth. The calendar plugin asks for read and write permission together, but DaPri never changes anything in your calendar.

## Development

```bash
flutter pub get
flutter test          # date parser and availability logic
flutter run           # on a connected phone or emulator
flutter build apk     # build/app/outputs/flutter-apk/
```

Code layout:

- `lib/datumprikker_driver.dart`: controls the Datumprikker page in a WebView (the equivalent of the Selenium part of the original script)
- `lib/date_parser.dart`: parses Dutch date texts such as "ma 12 okt 19:00 - 22:00"
- `lib/availability.dart`: turns calendar events into a suggested answer
- `lib/calendar_service.dart`: reads the device calendars (Android and iOS via `device_calendar_plus`)
- `lib/screens/`: home, review, and settings screens

The page selectors (`.eventdate`, `li.yes`, `#nav_next`, `#eventname`, …) come from the original script. If Datumprikker changes its site, `datumprikker_driver.dart` needs updating. Use the globe icon in the app to watch the page while it's being filled in.

### iOS

The iOS project and calendar permission texts are already set up. Building for iOS requires a Mac with Xcode.
