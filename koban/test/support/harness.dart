import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
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
import 'package:koban/online/google_accounts.dart';
import 'package:koban/online/online_config.dart';
import 'package:koban/online/online_services.dart';
import 'package:koban/online/secret_store.dart';
import 'package:koban/receipts/receipt_photos.dart';
import 'package:koban/receipts/receipt_reader.dart';
import 'package:koban/rules/receipt_rules.dart';
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

/// A fake receipt OCR. It gives the lines of [byPath] for a path. A path in [failing] throws.
/// A path in [later] answers when the test completes its completer.
/// A path in none of them gives no lines.
class FakeReceiptOcr implements ReceiptOcr {
  FakeReceiptOcr(this.byPath, {this.failing = const {}, this.later = const {}});

  final Map<String, List<OcrLine>> byPath;
  final Set<String> failing;
  final Map<String, Completer<List<OcrLine>>> later;

  @override
  Future<List<OcrLine>> lines(String path) async {
    if (failing.contains(path)) throw StateError('OCR failed');
    final wait = later[path];
    if (wait != null) return wait.future;
    return byPath[path] ?? const [];
  }
}

/// A fake photo source. Each call to [scan] gives the next of [answers] (null is a cancel).
class FakeReceiptPhotos implements ReceiptPhotos {
  FakeReceiptPhotos(this.answers);

  final List<String?> answers;

  /// How many times [scan] ran.
  int scans = 0;

  @override
  Future<String?> scan() async => answers[scans++];
}

/// App services on an in-memory database with the categories seeded.
/// The clock stops at [now] (default: Friday 13 Nov 2026, 12:00).
/// [checkHold] is the Undo window of Check payments.
/// [filesDir] is the folder for the QR pictures (default: a new temp folder that the test deletes).
/// [pickImage] is the photo picker (default: the user cancels).
/// [cacheDir] is the app cache folder where the picker copies pictures (default: [filesDir]).
/// [ocr] reads receipt photos (default: no lines). [photos] takes receipt photos (default: the user cancels).
/// [secrets] fills the secrets store (a second in-memory store).
/// [http] is the HTTP client. The default client records each request, and the tear-down
/// fails the test when it recorded one: no test may reach the network. A test that expects
/// requests gives its own client.
/// [google] is the Google sign-in (default: the phone sign-in, which no test may start).
/// The database closes after the widget tree is gone.
Future<AppServices> testServices({
  DateTime? now,
  Map<String, Object> prefs = const {},
  ImportResult importResult = const ImportSkipped(),
  FakeChannel? listener,
  FakeChannel? device,
  Duration checkHold = const Duration(milliseconds: 4000),
  Directory? filesDir,
  Future<String?> Function()? pickImage,
  Directory? cacheDir,
  http.Client? http,
  Map<String, Object> secrets = const {},
  GoogleAccounts? google,
  ReceiptOcr? ocr,
  ReceiptPhotos? photos,
}) async {
  final time = now ?? DateTime(2026, 11, 13, 12);
  final previous = SharedPreferencesAsyncPlatform.instance;
  addTearDown(() => SharedPreferencesAsyncPlatform.instance = previous);
  // Each SharedPreferencesAsync keeps the store that is current when it is made.
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(secrets);
  final secretStore = SecretStore(SharedPreferencesAsync());
  await secretStore.load();
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.withData(prefs);
  listener ??= FakeChannel(ListenerControl.channelName, {
    'isAccessGranted': true,
    'isConnected': true,
  });
  device ??= FakeChannel(deviceChannelName, {});
  final db = KobanDatabase(NativeDatabase.memory(setup: configureConnection));
  addTearDown(db.close);
  if (filesDir == null) {
    final temp = Directory.systemTemp.createTempSync('koban_files');
    addTearDown(() {
      if (temp.existsSync()) temp.deleteSync(recursive: true);
    });
    filesDir = temp;
  }
  final root = filesDir;
  final host = FakeCaptureHost();
  final settings = await KobanSettings.load(
    SharedPreferencesAsync(),
    secrets: secretStore,
  );
  final unexpected = <String>[];
  if (http == null) {
    // An app catch can hide the failure in the request. The tear-down cannot be hidden.
    addTearDown(
      () => expect(unexpected, isEmpty, reason: 'unexpected requests'),
    );
  }
  final s = AppServices(
    db: db,
    settings: settings,
    importResult: importResult,
    listener: ListenerControl(),
    paymentApps: PaymentApps(SharedPreferencesAsync(), host),
    captureHost: host,
    device: DeviceControl(),
    online: OnlineServices(
      config: OnlineConfig.test,
      http:
          http ??
          MockClient((r) async {
            unexpected.add('${r.method} ${r.url.path}');
            fail('unexpected request ${r.method} ${r.url.path}');
          }),
      secrets: secretStore,
      settings: settings,
      db: db,
      now: () => time,
      google: google,
    ),
    now: () => time,
    checkHold: checkHold,
    filesDir: () async => root,
    cacheDir: () async => cacheDir ?? root,
    pickImage: pickImage ?? () async => null,
    ocr: ocr ?? FakeReceiptOcr(const {}),
    photos: photos ?? FakeReceiptPhotos([null]),
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
    // The Supabase client, when the test made one, stops with its JSON isolate.
    // The isolate starts and stops on real time: wait for it 5 s at most.
    var stopped = false;
    s.online.dispose().whenComplete(() => stopped = true).ignore();
    // With no client the dispose ends here, and no real time runs: a file
    // read of the test stays where it is.
    await tester.pump();
    for (var i = 0; i < 250 && !stopped; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(stopped, isTrue, reason: 'the Supabase client did not stop in 5 s');
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
