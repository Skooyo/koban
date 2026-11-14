import 'dart:ui' show DartPluginRegistrant;

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_services.dart';
import 'app/koban_app.dart';
import 'capture/capture_host.dart';
import 'capture/capture_main.dart';
import 'data/legacy_import.dart' show describeError;
import 'data/open_database.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final AppServices s;
  try {
    s = await AppServices.start();
  } catch (e) {
    // The app cannot run without its data. Stop as 0.1.1 did.
    debugPrint('Koban start failed: ${describeError(e)}');
    rethrow;
  }
  runApp(
    AppScope(
      services: s,
      child: KobanApp(services: s),
    ),
  );
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
    debugPrint('Capture start failed: ${describeError(e)}');
  }
}
