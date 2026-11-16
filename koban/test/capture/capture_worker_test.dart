import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/capture/capture_host.dart';
import 'package:koban/capture/capture_worker.dart';
import 'package:koban/capture/payment_apps.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/data/pending_payment_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'fake_capture_host.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';
const qrText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
const T = 1762000000000;
const P = T - 60000;

QueuedNotification row(
  int id,
  String pkg,
  String text, {
  int postTime = P,
  String? key,
}) => QueuedNotification(
  id: id,
  logId: 'log-$id',
  packageName: pkg,
  title: null,
  text: text,
  postTime: postTime,
  notificationKey: key,
);

void main() {
  late KobanDatabase db;
  late FakeCaptureHost host;
  late SharedPreferencesAsync prefs;
  late CaptureWorker worker;

  Future<int> countPending(KobanDatabase d) async =>
      (await d
              .customSelect('SELECT COUNT(*) AS c FROM pending_payments')
              .getSingle())
          .read<int>('c');

  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    db = KobanDatabase(NativeDatabase.memory(setup: configureConnection));
    host = FakeCaptureHost();
    worker = CaptureWorker(
      host: host,
      payments: PendingPaymentRepository(db, now: () => T),
      paymentApps: PaymentApps(prefs, host),
    );
  });
  tearDown(() => db.close());

  test(
    'a payment from a chosen app becomes a card and the log says WAITING',
    () async {
      await prefs.setStringList('payment_app_allowlist', [maybank]);
      host.queue.add(row(1, maybank, qrText, key: 'k1'));
      await worker.drain();
      expect(host.finished, [(1, 'WAITING', 'RESTORAN CONTOH · RM 15.00')]);
      expect(await countPending(db), 1);
    },
  );

  test('an app that is not chosen is skipped and acknowledged', () async {
    await prefs.setStringList('payment_app_allowlist', [tng]);
    host.queue.add(row(1, maybank, qrText));
    await worker.drain();
    expect(host.finished, [
      (1, 'SKIPPED_ALLOWLIST', 'Package not on allowlist'),
    ]);
    expect(await countPending(db), 0);
  });

  test('no chosen apps skips every app', () async {
    host.queue.addAll([row(1, maybank, qrText), row(2, tng, qrText)]);
    await worker.drain();
    expect(host.finished, [
      (1, 'SKIPPED_ALLOWLIST', 'Package not on allowlist'),
      (2, 'SKIPPED_ALLOWLIST', 'Package not on allowlist'),
    ]);
    expect(await countPending(db), 0);
  });

  test('a text with no amount is skipped and acknowledged', () async {
    await prefs.setStringList('payment_app_allowlist', [maybank]);
    host.queue.add(row(1, maybank, 'Your statement is ready.'));
    await worker.drain();
    expect(host.finished, [
      (1, 'SKIPPED_NO_RULE', 'No rule matched this text'),
    ]);
    expect(await countPending(db), 0);
  });

  test('a row that comes again after a crash makes one card', () async {
    await prefs.setStringList('payment_app_allowlist', [maybank]);
    host.queue.add(row(1, maybank, qrText, key: 'k1'));
    await worker.drain();
    host.queue.add(row(1, maybank, qrText, key: 'k1'));
    await worker.drain();
    expect(host.finished.map((f) => f.$2), ['WAITING', 'SKIPPED_DUPLICATE']);
    expect(host.finished.last.$3, 'Duplicate within dedup window');
    expect(await countPending(db), 1);
  });

  test('a save error keeps the row in the queue', () async {
    await prefs.setStringList('payment_app_allowlist', [maybank]);
    host.queue.add(row(1, maybank, qrText, key: 'k1'));
    await db.customStatement('DROP TABLE pending_payments');
    await worker.drain();
    expect(host.queue.map((r) => r.id), [1]);
    expect(host.finished, isEmpty);
    expect(host.logUpdates.single.$1, 'log-1');
    expect(host.logUpdates.single.$2, 'SKIPPED_ERROR');
  });

  test('rows that arrive during a drain are handled in the same run, each one time', () async {
    await prefs.setStringList('payment_app_allowlist', [maybank]);
    host.queue.add(row(1, maybank, qrText, key: 'k1'));
    var added = false;
    late Future<void> second;
    host.onTake = (afterId) {
      // The empty answer for afterId 1 is picked. A drain call and two
      // new rows come now, so only the run-again flag can handle them.
      if (afterId == 1 && !added) {
        added = true;
        second = worker.drain();
        host.queue.addAll([
          row(
            2,
            maybank,
            'Successful payment of RM 20.00 to KEDAI SATU. REF: QR000002.',
            key: 'k2',
          ),
          row(
            3,
            maybank,
            'Successful payment of RM 30.00 to KEDAI DUA. REF: QR000003.',
            key: 'k3',
          ),
        ]);
      }
    };
    await worker.drain();
    await second;
    expect(host.finished.map((f) => f.$1), [1, 2, 3]);
    expect(host.finished.map((f) => f.$2), ['WAITING', 'WAITING', 'WAITING']);
    expect(await countPending(db), 3);
  });

  test('a drain after a takeQueue error works', () async {
    await prefs.setStringList('payment_app_allowlist', [maybank]);
    host.queue.add(row(1, maybank, qrText, key: 'k1'));
    var failed = false;
    host.onTake = (afterId) {
      if (!failed) {
        failed = true;
        throw StateError('channel down');
      }
    };
    await expectLater(worker.drain(), throwsStateError);
    expect(host.finished, isEmpty);
    await worker.drain();
    expect(host.finished, [(1, 'WAITING', 'RESTORAN CONTOH · RM 15.00')]);
  });
}
