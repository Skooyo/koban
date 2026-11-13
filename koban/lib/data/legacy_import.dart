import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'legacy_source.dart';

/// The text that the app shows when the import fails.
const importFailedMessage =
    'Koban could not move your data. Your data is safe. Update again later.';

/// The 8 settings of 0.1.1 that the import copies.
const legacySettingKeys = <String>[
  'payment_app_allowlist',
  'payment_apps_chosen',
  'onboarding_done',
  'dark_mode',
  'online_features',
  'last_update_check',
  'device_token',
  'group_session',
];

/// The setting that is true after the rows are in the new database.
const importDoneKey = 'legacy_import_done';

/// The Room schema version that the import accepts.
const _legacyVersion = 11;

/// The result of one import attempt.
sealed class ImportResult {
  const ImportResult();
}

/// There was nothing to import, or the import was done before.
final class ImportSkipped extends ImportResult {
  const ImportSkipped();
}

/// The import copied all old rows. [rowCounts] is the old row count of each table.
final class ImportDone extends ImportResult {
  const ImportDone(this.rowCounts);

  final Map<String, int> rowCounts;
}

/// The import did not copy the rows. The old file did not change.
final class ImportFailed extends ImportResult {
  const ImportFailed(this.tables, this.detail);

  /// The tables that the import could not copy. Empty when no table caused the failure.
  final List<String> tables;

  /// The error text.
  final String detail;

  /// The line for the notification log.
  String get logLine => 'Data import failed: ${tables.join(', ')} ($detail)';
}

/// A failure that has its result ready.
class _Failure implements Exception {
  _Failure(this.result);

  final ImportFailed result;
}

/// Copies the 0.1.1 database and settings into Koban one time.
///
/// This function never throws. On failure, the old file stays where it is and
/// the next start tries again.
Future<ImportResult> importLegacyData({
  required KobanDatabase db,
  required LegacySource legacy,
  required SharedPreferencesAsync prefs,
}) async {
  try {
    // Step 1: the rows were copied before. Finish the rename if a crash stopped it.
    if (await prefs.getBool(importDoneKey) ?? false) {
      try {
        await _renameOldFiles(await legacy.databasePath());
      } catch (_) {
        // The rows are safe in the new database. The next start tries the rename again.
      }
      return const ImportSkipped();
    }

    // Step 2.
    final path = await legacy.databasePath();
    if (!await File(path).exists()) return const ImportSkipped();

    // Step 3: settings first, so capture keeps the payment app list if the table copy fails.
    await _copySettings(await legacy.readSettings(), prefs);

    // Steps 4 and 5.
    final counts = await _copyTables(db, path);

    // Step 6.
    await prefs.setBool(importDoneKey, true);

    // Step 7. The old connection is closed. The rows are committed and the mark is set,
    // so a rename failure is not an import failure: step 1 finishes the rename at the next start.
    try {
      await _renameOldFiles(path);
    } catch (_) {}
    return ImportDone(counts);
  } on _Failure catch (f) {
    return f.result;
  } catch (e) {
    return ImportFailed(const [], '$e');
  }
}

/// Writes each old setting that the new settings do not have.
Future<void> _copySettings(
    Map<String, Object?> settings, SharedPreferencesAsync prefs) async {
  for (final key in legacySettingKeys) {
    final value = settings[key];
    if (value == null || await prefs.containsKey(key)) continue;
    switch (value) {
      case List<String> v:
        await prefs.setStringList(key, v);
      case bool v:
        await prefs.setBool(key, v);
      case int v:
        await prefs.setInt(key, v);
      case String v:
        await prefs.setString(key, v);
      default:
        throw FormatException(
            'setting $key has the unknown type ${value.runtimeType}');
    }
  }
}

/// Copies the rows of the 11 tables in one transaction and returns the old row counts.
/// When a table fails, the transaction rolls back and nothing is copied.
Future<Map<String, int>> _copyTables(KobanDatabase db, String path) async {
  final (old, copyDir) = await _openOld(path);
  try {
    final version = old.userVersion;
    if (version != _legacyVersion) {
      throw _Failure(ImportFailed(
          const [], 'old database version $version, needs $_legacyVersion'));
    }
    final tables = {for (final t in db.allTables) t.actualTableName: t};
    final counts = <String, int>{};
    final failed = <String>[];
    final errors = <String>[];
    await db.transaction(() async {
      for (final name in legacyTableOrder) {
        try {
          final table = tables[name]!;
          final columns = [for (final c in table.$columns) c.name];
          final quoted = columns.map((c) => '"$c"').join(', ');
          // Select by name, so the column order of the old table has no effect.
          final rows = old.select('SELECT $quoted FROM "$name"').rows;
          final insert = 'INSERT OR REPLACE INTO "$name" ($quoted) '
              'VALUES (${List.filled(columns.length, '?').join(', ')})';
          // The raw stored values go in unchanged, with parameter binding.
          await db.batch((b) {
            for (final row in rows) {
              b.customStatement(insert, row);
            }
          });

          // Check that every old primary key is in the new table.
          final keys = [for (final c in table.$primaryKey) c.name];
          final keyIndexes = [for (final k in keys) columns.indexOf(k)];
          final newKeys = {
            for (final r in await db
                .customSelect(
                    'SELECT ${keys.map((k) => '"$k"').join(', ')} FROM "$name"')
                .get())
              jsonEncode(r.data.values.toList()),
          };
          final found = rows
              .where((row) =>
                  newKeys.contains(jsonEncode([for (final i in keyIndexes) row[i]])))
              .length;
          if (found != rows.length) {
            throw StateError(
                '$found of ${rows.length} old rows are in the new table');
          }
          counts[name] = rows.length;
        } catch (e) {
          failed.add(name);
          errors.add('$name: $e');
        }
      }
      // An error out of the transaction makes Drift roll back all tables.
      if (failed.isNotEmpty) {
        throw _Failure(ImportFailed(failed, errors.join('; ')));
      }
    });
    return counts;
  } finally {
    old.close();
    if (copyDir != null) {
      try {
        await copyDir.delete(recursive: true);
      } catch (_) {}
    }
  }
}

/// The folder for the copy of the old files. It is next to the old file,
/// because the app can always write there (the system temp folder can be
/// /data/local/tmp on Android, which the app cannot write).
Directory _copyDirFor(String path) =>
    Directory('${File(path).parent.path}/legacy_import_copy');

/// Opens the old file read-only. SQLite also reads the rows in the -wal file.
///
/// Never open the old file read-write: a read-write connection checkpoints
/// and changes it. If the read-only open fails (for example, a hot -journal
/// after a crash, or no -shm file and no write access), copy the .db, -wal and
/// -journal files next to the old file and open the copy read-write. Then
/// SQLite rolls back the hot journal or recovers the WAL in the copy only.
/// The second value is the copy folder, or null.
Future<(Database, Directory?)> _openOld(String path) async {
  try {
    final old = sqlite3.open(path, mode: OpenMode.readOnly);
    try {
      // The first read shows if the open works.
      old.userVersion;
      return (old, null);
    } catch (_) {
      old.close();
      rethrow;
    }
  } on SqliteException {
    final copyDir = _copyDirFor(path);
    try {
      // A copy folder from a stopped attempt is not trusted.
      if (await copyDir.exists()) await copyDir.delete(recursive: true);
      await copyDir.create();
      final copy = '${copyDir.path}/expense_tracker.db';
      await File(path).copy(copy);
      for (final suffix in const ['-wal', '-journal']) {
        final side = File('$path$suffix');
        if (await side.exists()) await side.copy('$copy$suffix');
      }
      return (sqlite3.open(copy, mode: OpenMode.readWrite), copyDir);
    } catch (_) {
      try {
        await copyDir.delete(recursive: true);
      } catch (_) {}
      rethrow;
    }
  }
}

/// Renames the old database file and its side files to `.pre-flutter` names.
/// The -wal name follows the .db name, so SQLite finds it when it opens the renamed file.
Future<void> _renameOldFiles(String path) async {
  for (final suffix in const ['', '-wal', '-shm', '-journal']) {
    final file = File('$path$suffix');
    if (await file.exists()) await file.rename('$path.pre-flutter$suffix');
  }
}
