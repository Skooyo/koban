import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:drift_flutter/drift_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/common.dart' show CommonDatabase;

import '../capture/capture_host.dart';
import '../capture/payment_apps.dart';
import 'database.dart';
import 'legacy_import.dart';
import 'legacy_source.dart';

/// The one open of this isolate. A second call gets the same database and result.
/// A failed open is not kept, so the next call tries again.
Future<(KobanDatabase, ImportResult)>? _opened;

/// Opens the Koban database and imports the 0.1.1 data one time.
/// Every entry point gets the database only from here.
Future<(KobanDatabase, ImportResult)> openKobanDatabase() =>
    _opened ??= _open().catchError((Object e, StackTrace s) {
      _opened = null;
      Error.throwWithStackTrace(e, s);
    });

Future<(KobanDatabase, ImportResult)> _open() async {
  final db = KobanDatabase(
    driftDatabase(
      name: 'koban',
      native: const DriftNativeOptions(setup: configureConnection),
    ),
  );
  // Only the Android app had a 0.1.1 version, and only Android has the gate.
  if (!Platform.isAndroid) return (db, const ImportSkipped());
  try {
    final prefs = SharedPreferencesAsync();
    final host = ChannelCaptureHost();
    final result = await openAndImport(
      db: db,
      runImport: () => importLegacyData(
        db: db,
        legacy: ChannelLegacySource(),
        prefs: prefs,
      ),
      host: host,
      paymentApps: PaymentApps(prefs, host),
    );
    return (db, result);
  } catch (_) {
    try {
      await db.close();
    } catch (_) {}
    rethrow;
  }
}

/// Opens [db] and runs [runImport] while this engine holds the import gate,
/// so only one engine at a time imports. The gate opens again on every path.
///
/// A problem with the import goes to the notification log. Then the saved
/// payment apps go to the native listener. An error of the log or of the
/// native copy does not stop the open: the rows are safe and the result tells
/// the app about the import.
Future<ImportResult> openAndImport({
  required KobanDatabase db,
  required Future<ImportResult> Function() runImport,
  required CaptureHost host,
  required PaymentApps paymentApps,
}) async {
  final ImportResult result;
  await host.acquireImportGate();
  try {
    // The first query opens the file and makes the schema.
    await db.customSelect('SELECT 1').get();
    result = await runImport();
  } finally {
    await host.releaseImportGate();
  }
  final logLine = switch (result) {
    ImportSkipped() => null,
    ImportDone(:final logLine) => logLine,
    ImportFailed(:final logLine) => logLine,
  };
  if (logLine != null) {
    try {
      await host.appendLog(
        'Data import',
        logLine,
        NotificationDisposition.skippedError,
        '',
      );
    } catch (e) {
      debugPrint('Koban: ${describeError(e)}');
    }
  }
  try {
    await paymentApps.syncToNative();
  } catch (e) {
    debugPrint('Koban: ${describeError(e)}');
  }
  return result;
}

/// Makes one connection wait up to 5 s for a lock. Top-level, because Drift sends it to the background isolate.
void configureConnection(CommonDatabase db) {
  db.execute('PRAGMA busy_timeout = 5000');
}
