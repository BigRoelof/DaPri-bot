import 'package:device_calendar_plus/device_calendar_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../availability.dart';
import '../calendar_service.dart';
import '../datumprikker_driver.dart';
import '../models.dart';
import '../settings.dart';

enum _Stage { loading, review, filling, done, error }

class PollScreen extends StatefulWidget {
  const PollScreen({
    super.key,
    required this.url,
    required this.settings,
    required this.calendar,
  });

  final Uri url;
  final Settings settings;
  final CalendarService calendar;

  @override
  State<PollScreen> createState() => _PollScreenState();
}

class _PollScreenState extends State<PollScreen> {
  final _driver = DatumprikkerDriver();
  _Stage _stage = _Stage.loading;
  String _step = '';
  String? _error;
  bool _showPage = false;

  List<PollOption> _options = [];
  final _suggestions = <PollOption, Suggestion>{};
  final _answers = <PollOption, Answer>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _onStep(String step) {
    if (mounted) setState(() => _step = step);
  }

  Future<void> _load() async {
    setState(() {
      _stage = _Stage.loading;
      _error = null;
    });
    try {
      _onStep('Toegang tot je agenda controleren…');
      if (!await widget.calendar.hasPermission() && !await widget.calendar.requestPermission()) {
        throw DatumprikkerException(
            'Zonder toegang tot je agenda kan DaPri je beschikbaarheid niet bepalen.');
      }

      final options = await _driver.open(widget.url, onStep: _onStep);
      if (options.isEmpty) throw DatumprikkerException('Deze Datumprikker heeft geen datums.');

      _onStep('Je agenda bekijken…');
      final parsed = options.where((o) => o.parsed).toList();
      final events = parsed.isEmpty
          ? <Event>[]
          : await widget.calendar.events(
              parsed.map((o) => o.start!).reduce((a, b) => a.isBefore(b) ? a : b)
                  .subtract(const Duration(days: 1)),
              parsed.map((o) => o.end!).reduce((a, b) => a.isAfter(b) ? a : b)
                  .add(const Duration(days: 1)),
            );

      _options = options;
      for (final option in options) {
        final suggestion = suggestAnswer(option, events);
        _suggestions[option] = suggestion;
        _answers[option] = suggestion.answer;
      }
      if (mounted) setState(() => _stage = _Stage.review);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = e is DatumprikkerException ? e.message : 'Er ging iets mis: $e';
        });
      }
    }
  }

  Future<void> _fill() async {
    setState(() => _stage = _Stage.filling);
    try {
      await _driver.fill(
        _answers,
        name: widget.settings.name,
        email: widget.settings.email,
        onStep: _onStep,
      );
      if (mounted) setState(() => _stage = _Stage.done);
    } catch (e) {
      if (mounted) {
        setState(() {
          _stage = _Stage.error;
          _error = e is DatumprikkerException ? e.message : 'Er ging iets mis: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageVisible = _stage == _Stage.done || _showPage;
    return Scaffold(
      appBar: AppBar(
        title: Text(switch (_stage) {
          _Stage.review => 'Controleer je beschikbaarheid',
          _Stage.done => 'Controleer en verstuur',
          _ => 'Datumprikker',
        }),
        actions: [
          if (_stage != _Stage.done)
            IconButton(
              tooltip: _showPage ? 'Verberg pagina' : 'Toon Datumprikker-pagina',
              icon: Icon(_showPage ? Icons.visibility_off_outlined : Icons.language),
              onPressed: () => setState(() => _showPage = !_showPage),
            ),
        ],
      ),
      // The WebView stays in the tree the whole time, under the app's own UI.
      body: Stack(
        children: [
          Positioned.fill(child: WebViewWidget(controller: _driver.controller)),
          if (!pageVisible)
            Positioned.fill(
              child: ColoredBox(
                color: Theme.of(context).colorScheme.surface,
                child: switch (_stage) {
                  _Stage.review => _buildReview(context),
                  _Stage.error => _buildError(context),
                  _ => _buildProgress(context),
                },
              ),
            ),
          if (_stage == _Stage.done) _buildDoneBanner(context),
        ],
      ),
      bottomNavigationBar: _stage == _Stage.review && !_showPage ? _buildFillBar(context) : null,
    );
  }

  Widget _buildProgress(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(_step, style: Theme.of(context).textTheme.bodyLarge),
          ],
        ),
      );

  Widget _buildError(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
              const SizedBox(height: 16),
              Text(_error ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton.tonal(onPressed: _load, child: const Text('Opnieuw proberen')),
              TextButton(
                onPressed: () => setState(() => _showPage = true),
                child: const Text('Pagina zelf bekijken'),
              ),
            ],
          ),
        ),
      );

  Widget _buildReview(BuildContext context) {
    final counts = {
      for (final a in Answer.values) a: _answers.values.where((v) => v == a).length,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final a in [Answer.yes, Answer.maybe, Answer.no, Answer.skip])
              if (counts[a]! > 0)
                Chip(
                  avatar: Icon(_icon(a), size: 18, color: _color(context, a)),
                  label: Text('${counts[a]} ${a.label.toLowerCase()}'),
                ),
          ],
        ),
        const SizedBox(height: 8),
        for (final option in _options)
          _OptionCard(
            option: option,
            suggestion: _suggestions[option]!,
            answer: _answers[option]!,
            onChanged: (a) => setState(() => _answers[option] = a),
          ),
      ],
    );
  }

  Widget _buildFillBar(BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: _fill,
            icon: const Icon(Icons.edit_calendar),
            label: const Text('Invullen op Datumprikker'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          ),
        ),
      );

  Widget _buildDoneBanner(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      child: Material(
        color: scheme.primaryContainer,
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, color: scheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Alles is ingevuld. Controleer de pagina en verstuur hem zelf.',
                  style: TextStyle(color: scheme.onPrimaryContainer),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.option,
    required this.suggestion,
    required this.answer,
    required this.onChanged,
  });

  final PollOption option;
  final Suggestion suggestion;
  final Answer answer;
  final ValueChanged<Answer> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final answers = [Answer.yes, Answer.maybe, Answer.no]
        .where(option.answerClasses.containsKey)
        .toList();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_icon(answer), color: _color(context, answer)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        option.parsed
                            ? _capitalize(DateFormat('EEEE d MMMM').format(option.start!))
                            : option.text,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        !option.parsed
                            ? 'Datum niet herkend, kies zelf'
                            : option.allDay
                                ? 'Hele dag'
                                : '${_time(option.start!)} – ${_time(option.end!)}',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (option.parsed) ...[
              const SizedBox(height: 8),
              if (suggestion.conflicts.isEmpty)
                Text('Niets in je agenda', style: theme.textTheme.bodySmall)
              else
                for (final e in suggestion.conflicts)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Row(
                      children: [
                        Icon(Icons.event, size: 16, color: theme.colorScheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${e.isAllDay ? 'Hele dag' : '${_time(e.startDate)}–${_time(e.endDate)}'}'
                            '  ${e.title}',
                            style: theme.textTheme.bodySmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
            const SizedBox(height: 12),
            if (answers.isEmpty)
              Text('Geen antwoordknoppen gevonden voor deze datum.',
                  style: theme.textTheme.bodySmall)
            else
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<Answer>(
                  segments: [
                    for (final a in answers)
                      ButtonSegment(value: a, label: Text(a.label), icon: Icon(_icon(a))),
                  ],
                  selected: {if (answer != Answer.skip) answer},
                  emptySelectionAllowed: true,
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => onChanged(s.isEmpty ? Answer.skip : s.first),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime t) => DateFormat.Hm().format(t);

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

IconData _icon(Answer a) => switch (a) {
      Answer.yes => Icons.check_circle,
      Answer.maybe => Icons.help,
      Answer.no => Icons.cancel,
      Answer.skip => Icons.radio_button_unchecked,
    };

Color _color(BuildContext context, Answer a) => switch (a) {
      Answer.yes => const Color(0xFF2E9E5B),
      Answer.maybe => const Color(0xFFE0A100),
      Answer.no => Theme.of(context).colorScheme.error,
      Answer.skip => Theme.of(context).colorScheme.outline,
    };
