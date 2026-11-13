import 'dart:io';

import 'package:drift_flutter/drift_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'legacy_import.dart';
import 'legacy_source.dart';

/// The one open of this isolate. A second call gets the same database and result.
Future<(KobanDatabase, ImportResult)>? _opened;

/// Opens the Koban database and imports the 0.1.1 data one time.
/// Every entry point gets the database only from here.
Future<(KobanDatabase, ImportResult)> openKobanDatabase() =>
    _opened ??= _open();

Future<(KobanDatabase, ImportResult)> _open() async {
  final db = KobanDatabase(driftDatabase(name: 'koban'));
  // Only the Android app had a 0.1.1 version.
  final result = Platform.isAndroid
      ? await importLegacyData(
          db: db, legacy: ChannelLegacySource(), prefs: SharedPreferencesAsync())
      : const ImportSkipped();
  return (db, result);
}
