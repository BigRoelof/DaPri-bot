import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';

import '../calendar_service.dart';
import '../settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.settings, required this.calendar});

  final Settings settings;
  final CalendarService calendar;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final _name = TextEditingController(text: widget.settings.name);
  late final _email = TextEditingController(text: widget.settings.email);
  List<Calendar>? _calendars;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _loadCalendars(request: false);
  }

  @override
  void dispose() {
    _save();
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  void _save() => widget.settings.setDetails(name: _name.text, email: _email.text);

  Future<void> _loadCalendars({required bool request}) async {
    final granted = request
        ? await widget.calendar.requestPermission()
        : await widget.calendar.hasPermission();
    if (!granted) {
      setState(() => _permissionDenied = true);
      return;
    }
    final calendars = await widget.calendar.calendars();
    if (mounted) {
      setState(() {
        _permissionDenied = false;
        _calendars = calendars;
      });
    }
  }

  Future<void> _toggle(Calendar calendar, bool included) async {
    final excluded = {...?widget.settings.excludedCalendarIds};
    included ? excluded.remove(calendar.id) : excluded.add(calendar.id);
    await widget.settings.setExcludedCalendarIds(excluded);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final excluded = widget.settings.excludedCalendarIds ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Instellingen')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('Je gegevens', style: theme.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Naam',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            child: TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mailadres (optioneel)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.mail_outline),
              ),
              onChanged: (_) => _save(),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text('Agenda\'s om mee te tellen', style: theme.textTheme.titleMedium),
          ),
          if (_permissionDenied)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('DaPri heeft toegang tot je agenda nodig om te zien wanneer je kunt.'),
                  const SizedBox(height: 12),
                  FilledButton.tonal(
                    onPressed: () => _loadCalendars(request: true),
                    child: const Text('Toegang geven'),
                  ),
                  TextButton(
                    onPressed: widget.calendar.openAppSettings,
                    child: const Text('Open app-instellingen'),
                  ),
                ],
              ),
            )
          else if (_calendars == null)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_calendars!.isEmpty)
            const ListTile(title: Text('Geen agenda\'s gevonden op deze telefoon.'))
          else
            for (final c in _calendars!)
              SwitchListTile(
                secondary: CircleAvatar(
                  radius: 8,
                  backgroundColor: c.color ?? theme.colorScheme.primary,
                ),
                title: Text(c.name),
                subtitle: c.accountName == null ? null : Text(c.accountName!),
                value: !excluded.contains(c.id),
                onChanged: (v) => _toggle(c, v),
              ),
        ],
      ),
    );
  }
}
