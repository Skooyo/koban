import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/capture_host.dart';
import 'package:koban/capture/capture_main.dart';
import 'package:koban/capture/payment_apps.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/legacy_import.dart';
import 'package:koban/data/open_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import '../data/legacy_import_test.dart' show FakeLegacySource;
import '../data/test_db.dart';
import 'fake_capture_host.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';
const qrText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
const P = 1762000000000 - 60000;

QueuedNotification row(int id, String pkg, String text) => QueuedNotification(
  id: id,
  logId: 'log-$id',
  packageName: pkg,
  title: null,
  text: text,
  postTime: P,
  notificationKey: 'k$id',
);

void main() {
  late Directory tmp;
  late KobanDatabase db;
  late FakeCaptureHost host;
  late SharedPreferencesAsync prefs;

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koban_capture_main_');
    db = KobanDatabase(
      NativeDatabase(File('${tmp.path}/koban.sqlite'), setup: configureConnection),
    );
    host = FakeCaptureHost();
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
  });

  tearDown(() async {
    await db.close();
    await tmp.delete(recursive: true);
  });

  /// Open as the app does: the real import of a copy of the fixture, inside the gate.
  Future<(KobanDatabase, ImportResult)> openWithImport() async {
    final oldPath = '${tmp.path}/expense_tracker.db';
    File('test/fixtures/room_v11.db').copySync(oldPath);
    final result = await openAndImport(
      db: db,
      runImport: () => importLegacyData(
        db: db,
        legacy: FakeLegacySource(oldPath),
        prefs: prefs,
      ),
      host: host,
      paymentApps: PaymentApps(prefs, host),
    );
    return (db, result);
  }

  // Review Focus 3.
  test('a row queued before Dart started is captured after the import', () async {
    host.queue.add(row(1, maybank, qrText));
    await runCapture(host: host, open: openWithImport, prefs: prefs);
    expect(host.paymentApps, {maybank, tng});
    expect(host.finished.single.$2, 'WAITING');
    expect(host.finished, [(1, 'WAITING', 'RESTORAN CONTOH · RM 15.00')]);
    expect(host.queue, isEmpty);
    // 2 from the fixture + 1.
    expect((await rowCountsOf(db))['pending_payments'], 3);
  });

  test('a drain call after start runs the worker', () async {
    host.queue.add(row(1, maybank, qrText));
    await runCapture(host: host, open: openWithImport, prefs: prefs);
    host.queue.add(
      row(2, maybank, 'Successful payment of RM 8.00 to KOPI CONTOH. REF: 123456Q.'),
    );
    await host.triggerDrain();
    expect(host.finished, [
      (1, 'WAITING', 'RESTORAN CONTOH · RM 15.00'),
      (2, 'WAITING', 'KOPI CONTOH · RM 8.00'),
    ]);
    expect(host.queue, isEmpty);
    expect((await rowCountsOf(db))['pending_payments'], 4);
  });

  // Ruling R3.
  test('a drain call after a failed open opens again and captures the row', () async {
    await prefs.setStringList(PaymentApps.allowlistKey, [maybank]);
    host.queue.add(row(1, maybank, qrText));
    var opens = 0;
    Future<(KobanDatabase, ImportResult)> open() async {
      opens++;
      if (opens == 1) throw StateError('disk not ready');
      return (db, const ImportSkipped());
    }

    await expectLater(
      runCapture(host: host, open: open, prefs: prefs),
      throwsStateError,
    );
    expect(host.finished, isEmpty);
    expect(host.queue.length, 1);

    await host.triggerDrain();
    expect(opens, 2);
    expect(host.finished, [(1, 'WAITING', 'RESTORAN CONTOH · RM 15.00')]);
    expect(host.queue, isEmpty);
  });
}
