import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../calendar_service.dart';
import '../datumprikker_driver.dart';
import '../settings.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.settings,
    required this.calendar,
    required this.onOpenPoll,
  });

  final Settings settings;
  final CalendarService calendar;
  final void Function(Uri) onOpenPoll;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _link = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _link.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final link = DatumprikkerDriver.findLink(data?.text ?? '');
    setState(() {
      if (link != null) {
        _link.text = link.toString();
        _error = null;
      } else {
        _error = 'Geen Datumprikker-link op het klembord gevonden.';
      }
    });
  }

  void _start() {
    final link = DatumprikkerDriver.findLink(_link.text);
    if (link == null) {
      setState(() => _error = 'Plak een link die begint met https://datumprikker.nl/');
      return;
    }
    setState(() => _error = null);
    widget.onOpenPoll(link);
  }

  void _openSettings() => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SettingsScreen(settings: widget.settings, calendar: widget.calendar),
      ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('DaPri'),
        actions: [
          IconButton(
            tooltip: 'Instellingen',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: widget.settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Icon(Icons.event_available, size: 72, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              'Datumprikker invullen\nop basis van je agenda',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Deel een Datumprikker-link met DaPri, of plak hem hieronder. '
              'Je ziet eerst een voorstel dat je kunt aanpassen.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 28),
            if (!widget.settings.isComplete) ...[
              Card(
                color: theme.colorScheme.secondaryContainer,
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('Stel eerst je naam in'),
                  subtitle: const Text('Die vult DaPri in op Datumprikker.'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _openSettings,
                ),
              ),
              const SizedBox(height: 16),
            ],
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Datumprikker-link',
                hintText: 'https://datumprikker.nl/…',
                border: const OutlineInputBorder(),
                errorText: _error,
                suffixIcon: IconButton(
                  tooltip: 'Plakken',
                  icon: const Icon(Icons.content_paste),
                  onPressed: _paste,
                ),
              ),
              onSubmitted: (_) => _start(),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: widget.settings.isComplete ? _start : null,
              icon: const Icon(Icons.auto_fix_high),
              label: const Text('Beschikbaarheid bepalen'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
            ),
          ],
        ),
      ),
    );
  }
}
