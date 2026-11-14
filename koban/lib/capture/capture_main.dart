import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../data/legacy_import.dart' show ImportResult;
import '../data/pending_payment_repository.dart';
import 'capture_host.dart';
import 'capture_worker.dart';
import 'payment_apps.dart';

/// Starts capture in the background engine.
///
/// The drain handler is set first, so a native `drain` call always has a
/// listener. When [open] fails, this function throws, and the next `drain`
/// call tries to open again and then reads the queue. After the open, the
/// worker reads the rows that the queue got before Dart was ready.
Future<CaptureWorker> runCapture({
  required CaptureHost host,
  required Future<(KobanDatabase, ImportResult)> Function() open,
  required SharedPreferencesAsync prefs,
}) async {
  Future<CaptureWorker>? starting;

  Future<CaptureWorker> start() async {
    final (db, _) = await open();
    return CaptureWorker(
      host: host,
      payments: PendingPaymentRepository(db),
      paymentApps: PaymentApps(prefs, host),
    );
  }

  // A failed start is not kept, so the next call tries again.
  Future<CaptureWorker> ready() =>
      starting ??= start().catchError((Object e, StackTrace s) {
        starting = null;
        Error.throwWithStackTrace(e, s);
      });

  host.onDrain(() async => (await ready()).drain());
  final worker = await ready();
  await worker.drain();
  return worker;
}
