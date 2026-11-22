import 'dart:ui' show DartPluginRegistrant;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_services.dart';
import 'app/koban_app.dart';
import 'capture/capture_host.dart';
import 'capture/capture_main.dart';
import 'data/open_database.dart';
import 'theme/koban_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(await appRoot(AppServices.start));
}

/// The text of the page that shows when the app cannot start.
const startFailedMessage =
    'Koban could not start. Close Koban and open it again.';

/// The app, or a one-line error page when [start] fails.
/// Without a page, the Android splash stays on the screen.
Future<Widget> appRoot(Future<AppServices> Function() start) async {
  try {
    final s = await start();
    return AppScope(
      services: s,
      child: KobanApp(services: s),
    );
  } catch (e) {
    // The log has the error type only: no path and no value.
    debugPrint('Koban start failed: ${e.runtimeType}');
    return MaterialApp(
      title: 'Koban',
      debugShowCheckedModeBanner: false,
      theme: kobanTheme(Brightness.light),
      darkTheme: kobanTheme(Brightness.dark),
      home: const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(startFailedMessage, textAlign: TextAlign.center),
            ),
          ),
        ),
      ),
    );
  }
}

/// The entry point of the capture engine. It is in this file because the
/// native `DartEntrypoint(path, "captureMain")` looks in the root library.
@pragma('vm:entry-point')
Future<void> captureMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  try {
    await runCapture(
      host: ChannelCaptureHost(),
      open: openKobanDatabase,
      prefs: SharedPreferencesAsync(),
    );
  } catch (e) {
    // The drain handler stays set. The next drain call tries again.
    debugPrint('Capture start failed: ${e.runtimeType}');
  }
}
