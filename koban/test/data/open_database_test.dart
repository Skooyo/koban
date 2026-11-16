import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/payment_apps.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/legacy_import.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/online/secret_store.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../capture/fake_capture_host.dart';
import 'legacy_import_test.dart' show FakeLegacySource;
import 'test_db.dart';

void main() {
  // The Review Focus 4 test opens two databases on one file on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  late KobanDatabase db;
  late FakeCaptureHost host;
  late SharedPreferencesAsync prefs;
  late SharedPreferencesAsync secretPrefs;

  KobanDatabase openFile() => KobanDatabase(
    NativeDatabase(
      File('${tmp.path}/koban.sqlite'),
      setup: configureConnection,
    ),
  );

  Future<ImportResult> run(Future<ImportResult> Function() runImport) =>
      openAndImport(
        db: db,
        runImport: runImport,
        host: host,
        paymentApps: PaymentApps(prefs, host),
        secrets: SecretStore(secretPrefs),
        settings: prefs,
      );

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koban_open_');
    db = openFile();
    host = FakeCaptureHost();
    // Each SharedPreferencesAsync keeps the store that is current when it is made.
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    secretPrefs = SharedPreferencesAsync();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  test(
    'the import runs inside the gate and the gate opens after an error',
    () async {
      bool? seenGateHeld;
      await expectLater(
        run(() async {
          seenGateHeld = host.gateHeld;
          throw StateError('x');
        }),
        throwsStateError,
      );
      expect(seenGateHeld, true);
      expect(host.gateHeld, false);
    },
  );

  test('a failed import goes to the notification log', () async {
    await run(() async => const ImportFailed(['owed_items'], 'x'));
    expect(host.appended, [
      (
        'Data import',
        'Data import failed: owed_items (x)',
        'SKIPPED_ERROR',
        '',
      ),
    ]);
  });

  test('a settings error goes to the notification log', () async {
    await run(() async => const ImportDone({}, settingsError: 'y'));
    expect(host.appended, [
      ('Data import', 'Settings import failed (y)', 'SKIPPED_ERROR', ''),
    ]);
  });

  test('a clean import writes no log row', () async {
    final result = await run(() async => const ImportDone({'expenses': 4}));
    expect(result, isA<ImportDone>());
    expect(host.appended, isEmpty);
    expect(host.gateHeld, false);
  });

  test('the payment apps go to native after the import', () async {
    await run(() async {
      await prefs.setStringList(PaymentApps.allowlistKey, [
        'com.maybank2u.life',
        'my.com.tngdigital.ewallet',
      ]);
      return const ImportSkipped();
    });
    expect(host.paymentApps, {
      'com.maybank2u.life',
      'my.com.tngdigital.ewallet',
    });
  });

  // Review Focus 4.
  test('two opens at the same time import the 0.1.1 data one time', () async {
    final oldPath = '${tmp.path}/expense_tracker.db';
    File('test/fixtures/room_v11.db').copySync(oldPath);
    final legacy = FakeLegacySource(oldPath);
    final a = db;
    final b = openFile();
    addTearDown(b.close);

    Future<ImportResult> openOne(KobanDatabase d) => openAndImport(
      db: d,
      runImport: () => importLegacyData(db: d, legacy: legacy, prefs: prefs),
      host: host,
      paymentApps: PaymentApps(prefs, host),
      secrets: SecretStore(secretPrefs),
      settings: prefs,
    );

    final results = await Future.wait([openOne(a), openOne(b)]);
    expect(results.whereType<ImportDone>().length, 1);
    expect(results.whereType<ImportSkipped>().length, 1);
    expect(await rowCountsOf(a), fixtureCounts);
    expect(await rowCountsOf(b), fixtureCounts);
    expect(host.gateHeld, false);
    expect(host.appended, isEmpty);
  });

  test(
    'an open with no import moves the secrets of an earlier import',
    () async {
      await prefs.setString('device_token', 'test-device-token');
      await prefs.setString('group_session', '{"refresh_token":"r1"}');

      await run(() async => const ImportSkipped());

      expect(await prefs.getString('device_token'), isNull);
      expect(await prefs.getString('group_session'), isNull);
      expect(await secretPrefs.getString('device_token'), 'test-device-token');
      expect(
        await secretPrefs.getString('group_session'),
        '{"refresh_token":"r1"}',
      );
    },
  );
}
