import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'calendar_service.dart';
import 'datumprikker_driver.dart';
import 'screens/home_screen.dart';
import 'screens/poll_screen.dart';
import 'settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nl';
  await initializeDateFormatting('nl');
  final settings = await Settings.load();
  runApp(DaPriApp(settings: settings));
}

class DaPriApp extends StatefulWidget {
  const DaPriApp({super.key, required this.settings});

  final Settings settings;

  @override
  State<DaPriApp> createState() => _DaPriAppState();
}

class _DaPriAppState extends State<DaPriApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final _calendar = CalendarService(widget.settings);
  StreamSubscription<List<SharedMediaFile>>? _shareSub;

  @override
  void initState() {
    super.initState();
    // Links shared to the app, or datumprikker.nl links opened with it.
    _shareSub = ReceiveSharingIntent.instance.getMediaStream().listen(_onShared);
    ReceiveSharingIntent.instance.getInitialMedia().then((files) {
      _onShared(files);
      ReceiveSharingIntent.instance.reset();
    });
  }

  @override
  void dispose() {
    _shareSub?.cancel();
    super.dispose();
  }

  void _onShared(List<SharedMediaFile> files) {
    for (final file in files) {
      final link = DatumprikkerDriver.findLink('${file.path} ${file.message ?? ''}');
      if (link != null) {
        // Wait for the first frame so the navigator exists on a cold start.
        WidgetsBinding.instance.addPostFrameCallback((_) => openPoll(link));
        return;
      }
    }
  }

  void openPoll(Uri link) {
    _navigatorKey.currentState?.push(MaterialPageRoute(
      builder: (_) => PollScreen(url: link, settings: widget.settings, calendar: _calendar),
    ));
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness brightness) => ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF1B8A6B),
            brightness: brightness,
          ),
          useMaterial3: true,
        );

    return MaterialApp(
      navigatorKey: _navigatorKey,
      title: 'DaPri',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: HomeScreen(
        settings: widget.settings,
        calendar: _calendar,
        onOpenPoll: openPoll,
      ),
    );
  }
}
