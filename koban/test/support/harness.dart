import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/app/koban_app.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/capture/payment_apps.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/legacy_import.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/data/settings_store.dart';
import 'package:koban/device/device_control.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../capture/fake_capture_host.dart';

/// A fake native method channel. It records each call and gives the answer of [answers].
class FakeChannel {
  FakeChannel(String name, this.answers) {
    final channel = MethodChannel(name);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return answers[call.method];
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  }

  /// The answer to each method name. A test can change it.
  final Map<String, Object?> answers;
  final List<MethodCall> calls = [];
}

/// The name of the device channel of [DeviceControl].
const deviceChannelName = 'io.github.skooyo.koban/device';

/// App services on an in-memory database with the categories seeded.
/// The clock stops at [now] (default: Friday 13 Nov 2026, 12:00).
/// [checkHold] is the Undo window of Check payments.
/// The database closes after the widget tree is gone.
Future<AppServices> testServices({
  DateTime? now,
  Map<String, Object> prefs = const {},
  ImportResult importResult = const ImportSkipped(),
  FakeChannel? listener,
  FakeChannel? device,
  Duration checkHold = const Duration(milliseconds: 4000),
}) async {
  final time = now ?? DateTime(2026, 11, 13, 12);
  final previous = SharedPreferencesAsyncPlatform.instance;
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(prefs);
  listener ??= FakeChannel(ListenerControl.channelName, {
    'isAccessGranted': true,
    'isConnected': true,
  });
  device ??= FakeChannel(deviceChannelName, {});
  final db = KobanDatabase(NativeDatabase.memory(setup: configureConnection));
  addTearDown(db.close);
  final host = FakeCaptureHost();
  final s = AppServices(
    db: db,
    settings: await KobanSettings.load(SharedPreferencesAsync()),
    importResult: importResult,
    listener: ListenerControl(),
    paymentApps: PaymentApps(SharedPreferencesAsync(), host),
    captureHost: host,
    device: DeviceControl(),
    now: () => time,
    checkHold: checkHold,
  );
  await s.categories.seedIfEmpty();
  return s;
}

/// Pumps the app as `main` starts it. [home] replaces the tab shell when given.
/// [autoOpen] turns on the auto-open of the tab shell. It is off, so most tests start on Home.
Future<void> pumpKoban(
  WidgetTester tester,
  AppServices s, {
  Widget? home,
  double textScale = 1,
  bool disableAnimations = false,
  bool autoOpen = false,
}) async {
  // The tree goes first, so its streams end before the database closes.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData.fromView(tester.view).copyWith(
        alwaysUse24HourFormat: true,
        textScaler: TextScaler.linear(textScale),
        disableAnimations: disableAnimations,
      ),
      child: AppScope(
        services: s,
        child: KobanApp(
          services: s,
          home: home ?? HomeShell(autoOpen: autoOpen),
        ),
      ),
    ),
  );
}
