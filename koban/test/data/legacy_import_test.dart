import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/legacy_import.dart';
import 'package:koban/data/legacy_source.dart';
import 'package:koban/rules/types.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_db.dart';

const groupSessionJson =
    '{"access_token":"test-access","refresh_token":"test-refresh-0001",'
    '"expires_at":1762303600,"user_id":"00000000-0000-0000-0000-000000000001"}';

/// The 8 values of the Task 4 Kotlin test (LegacySettingsReaderTest).
const legacySettings = <String, Object?>{
  'payment_app_allowlist': <String>['com.maybank2u.life', 'my.com.tngdigital.ewallet'],
  'payment_apps_chosen': true,
  'onboarding_done': true,
  'dark_mode': false,
  'online_features': false,
  'last_update_check': 1762300000000,
  'device_token': 'test-device-token-0001',
  'group_session': groupSessionJson,
};

/// A legacy source with a fixed path and fixed settings.
class FakeLegacySource implements LegacySource {
  FakeLegacySource(this.path, {this.settingsError});

  final String path;

  /// When set, readSettings throws this error.
  final Object? settingsError;

  @override
  Future<String> databasePath() async => path;

  @override
  Future<Map<String, Object?>> readSettings() async {
    if (settingsError != null) throw settingsError!;
    return legacySettings;
  }
}

/// SQL that selects the stored values of one table as SQL literals, sorted
/// by primary key. quote() shows the storage type too: '12.50' is not 12.5.
String quotedSelect(TableInfo table) {
  final cols = [for (final c in table.$columns) 'quote("${c.name}")'];
  final pk = [for (final c in table.$primaryKey) '"${c.name}"'];
  return 'SELECT ${cols.join(', ')} FROM "${table.actualTableName}" '
      'ORDER BY ${pk.join(', ')}';
}

void main() {
  late Directory tmp;
  late String dir;
  late String oldPath;
  late KobanDatabase newDb;
  late SharedPreferencesAsync prefs;
  late LegacySource legacy;

  Future<ImportResult> run() =>
      importLegacyData(db: newDb, legacy: legacy, prefs: prefs);

  /// Change the copy of the old database (never the fixture).
  void changeOld(void Function(Database old) change) {
    final old = sqlite3.open(oldPath);
    try {
      change(old);
    } finally {
      old.close();
    }
  }

  /// Make the old file a WAL-mode file with expense 'w1' only in its -wal file
  /// and no -shm file. The .db file alone has the 4 fixture expenses.
  void writeWalOnlyRow() {
    Directory('$dir/writer').createSync();
    final writerPath = '$dir/writer/expense_tracker.db';
    File('test/fixtures/room_v11.db').copySync(writerPath);
    final writer = sqlite3.open(writerPath);
    writer.execute('PRAGMA journal_mode=WAL');
    writer.execute('PRAGMA wal_autocheckpoint=0');
    writer.execute(
        'INSERT INTO expenses (id, amount, currency, merchant, rawNotificationText, '
        'sourcePackage, notificationPostTime, createdAt, dedupKey, status, confidence, '
        'notificationKey, categoryId, notes, transactionType, countedAmount, privateToGroups) '
        "VALUES ('w1', '7.00', 'MYR', 'Wal Shop', 'raw w1', 'com.maybank2u.life', "
        "1762000240000, 1762000240500, 'dk-w1', 'AUTO_SAVED', 'HIGH', NULL, NULL, NULL, "
        "'WITHDRAW', NULL, 0)");
    // Copy the .db and -wal files (not -shm) while the writer is open.
    File(writerPath).copySync(oldPath);
    File('$writerPath-wal').copySync('$oldPath-wal');
    writer.close();
    expect(File('$oldPath-wal').lengthSync(), greaterThan(0));
    expect(File('$oldPath-shm').existsSync(), false);
    File(oldPath).copySync('$dir/db-only.db');
    final dbOnly = sqlite3.open('$dir/db-only.db', mode: OpenMode.readOnly);
    expect(dbOnly.select('SELECT COUNT(*) FROM expenses').first.columnAt(0), 4);
    dbOnly.close();
  }

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('koban_import_');
    dir = tmp.path;
    oldPath = '$dir/expense_tracker.db';
    File('test/fixtures/room_v11.db').copySync(oldPath);
    newDb = KobanDatabase(NativeDatabase(File('$dir/koban.sqlite')));
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    prefs = SharedPreferencesAsync();
    legacy = FakeLegacySource(oldPath);
  });

  tearDown(() async {
    await newDb.close();
    await tmp.delete(recursive: true);
  });

  test('imports every row of a real 0.1.1 database', () async {
    expect(await run(), isA<ImportDone>());
    expect(await rowCountsOf(newDb), fixtureCounts);
    final e1 = await (newDb.select(newDb.expenses)
          ..where((e) => e.id.equals('e1')))
        .getSingle();
    expect(e1.amount, Decimal.parse('12.50'));
    expect(e1.merchant, 'KEDAI Café ☕');
    expect(e1.rawNotificationText,
        'Pembayaran RM\u00a012.50 kepada KEDAI Café ☕ berjaya');
    expect(e1.status, ExpenseStatus.autoSaved);
    final e2 = await (newDb.select(newDb.expenses)
          ..where((e) => e.id.equals('e2')))
        .getSingle();
    expect(e2.countedAmount, Decimal.parse('411.33'));
    expect(e2.privateToGroups, true);
    expect(e2.merchant, null);
    final b1 = await (newDb.select(newDb.splitBills)
          ..where((b) => b.id.equals('b1')))
        .getSingle();
    expect(b1.rounding, Decimal.parse('-0.02'));
    final d2 = await (newDb.select(newDb.splitDebts)
          ..where((d) => d.id.equals('d2')))
        .getSingle();
    expect(d2.status, DebtStatus.paid);
    expect(d2.paidAt, 1762100000000);
    final p2 = await (newDb.select(newDb.pendingPayments)
          ..where((p) => p.id.equals('p2')))
        .getSingle();
    expect(p2.format, CaptureFormat.unknown);
    expect(p2.directionUnclear, true);
  });

  test('copies stored values without change', () async {
    expect(await run(), isA<ImportDone>());
    final old =
        sqlite3.open('$oldPath.pre-flutter', mode: OpenMode.readOnly);
    addTearDown(old.close);
    for (final table in newDb.allTables) {
      final name = table.actualTableName;
      final sql = quotedSelect(table);
      final oldRows = old.select(sql).rows;
      final newRows = [
        for (final row in await newDb.customSelect(sql).get())
          row.data.values.toList(),
      ];
      expect(oldRows.length, fixtureCounts[name], reason: name);
      expect(newRows, oldRows, reason: name);
    }
  });

  test('copies the 8 settings and keeps the group session JSON as it is',
      () async {
    expect(await run(), isA<ImportDone>());
    expect(await prefs.getStringList('payment_app_allowlist'),
        ['com.maybank2u.life', 'my.com.tngdigital.ewallet']);
    expect(await prefs.getBool('payment_apps_chosen'), true);
    expect(await prefs.getBool('onboarding_done'), true);
    expect(await prefs.getBool('dark_mode'), false);
    expect(await prefs.getBool('online_features'), false);
    expect(await prefs.getInt('last_update_check'), 1762300000000);
    expect(await prefs.getString('device_token'), 'test-device-token-0001');
    expect(await prefs.getString('group_session'), groupSessionJson);
  });

  test('marks the import done and renames the old file', () async {
    await run();
    expect(await prefs.getBool('legacy_import_done'), true);
    expect(File('$dir/expense_tracker.db').existsSync(), false);
    expect(File('$dir/expense_tracker.db.pre-flutter').existsSync(), true);
    expect(await run(), isA<ImportSkipped>());
    expect((await rowCountsOf(newDb))['expenses'], 4);
  });

  test('finishes the rename when the mark is set but the old file is still there',
      () async {
    await prefs.setBool(importDoneKey, true);
    expect(await run(), isA<ImportSkipped>());
    expect(File('$dir/expense_tracker.db').existsSync(), false);
    expect(File('$dir/expense_tracker.db.pre-flutter').existsSync(), true);
    expect(await rowCountsOf(newDb), {for (final t in fixtureCounts.keys) t: 0});
    expect(await prefs.getBool('dark_mode'), isNull);
  });

  // Review Focus 1
  test('copies rows that are only in the -wal file and moves the -wal file',
      () async {
    writeWalOnlyRow();
    final dbBytes = File(oldPath).readAsBytesSync();
    final walBytes = File('$oldPath-wal').readAsBytesSync();

    expect(await run(), isA<ImportDone>());
    expect((await rowCountsOf(newDb))['expenses'], 5);
    expect(File('$dir/expense_tracker.db-wal').existsSync(), false);
    expect(File('$dir/expense_tracker.db.pre-flutter-wal').existsSync(), true);
    // The read-only open did not checkpoint: both old files are unchanged.
    expect(File('$oldPath.pre-flutter').readAsBytesSync(), dbBytes);
    expect(File('$oldPath.pre-flutter-wal').readAsBytesSync(), walBytes);
    final moved =
        sqlite3.open('$oldPath.pre-flutter', mode: OpenMode.readOnly);
    expect(moved.select('SELECT COUNT(*) FROM expenses').first.columnAt(0), 5);
    moved.close();
  });

  // Controller ruling R1b
  test('copies the rows from a copy when the old file cannot be opened in place',
      () async {
    writeWalOnlyRow();
    // A folder with the -shm name makes the read-only open of the old file fail.
    Directory('$oldPath-shm').createSync();
    final dbBytes = File(oldPath).readAsBytesSync();
    final walBytes = File('$oldPath-wal').readAsBytesSync();

    expect(await run(), isA<ImportDone>());
    expect((await rowCountsOf(newDb))['expenses'], 5);
    expect(File('$oldPath.pre-flutter').readAsBytesSync(), dbBytes);
    expect(File('$oldPath.pre-flutter-wal').readAsBytesSync(), walBytes);
    expect(Directory('$dir/legacy_import_copy').existsSync(), false);
  });

  // Controller ruling R1b, review fix round 1
  test('rolls back a hot journal in the copy and imports the values before the crash',
      () async {
    // A writer on a separate copy stops in the middle of a commit in rollback
    // journal mode: the main file has some changed pages, and the -journal has
    // the original pages.
    Directory('$dir/writer').createSync();
    final writerPath = '$dir/writer/expense_tracker.db';
    File('test/fixtures/room_v11.db').copySync(writerPath);
    final writer = sqlite3.open(writerPath);
    writer.execute('PRAGMA journal_mode=DELETE');
    writer.execute('CREATE TABLE filler (b BLOB)');
    writer.execute('PRAGMA cache_size=10');
    writer.execute('PRAGMA cache_spill=10');
    writer.execute('BEGIN');
    writer.execute("UPDATE categories SET name = 'CHANGED'");
    writer.execute("UPDATE expenses SET amount = '999.99'");
    // More dirty pages than the cache holds: SQLite syncs the journal and
    // writes the changed pages to the main file before the commit.
    for (var i = 0; i < 200; i++) {
      writer.execute('INSERT INTO filler VALUES (zeroblob(4000))');
    }
    File(writerPath).copySync(oldPath);
    File('$writerPath-journal').copySync('$oldPath-journal');
    writer.close(); // The writer copy rolls back. The old copy keeps the hot journal.

    // The main file alone has the half-written values.
    File(oldPath).copySync('$dir/db-only.db');
    final dbOnly = sqlite3.open('$dir/db-only.db', mode: OpenMode.readOnly);
    expect(dbOnly.select("SELECT name FROM categories WHERE id = 'food'").first['name'],
        'CHANGED');
    dbOnly.close();
    final dbBytes = File(oldPath).readAsBytesSync();
    final journalBytes = File('$oldPath-journal').readAsBytesSync();

    expect(await run(), isA<ImportDone>());
    // Every imported value equals the value before the stopped commit.
    File('test/fixtures/room_v11.db').copySync('$dir/original.db');
    final original = sqlite3.open('$dir/original.db', mode: OpenMode.readOnly);
    addTearDown(original.close);
    for (final table in newDb.allTables) {
      final sql = quotedSelect(table);
      final newRows = [
        for (final row in await newDb.customSelect(sql).get())
          row.data.values.toList(),
      ];
      expect(newRows, original.select(sql).rows, reason: table.actualTableName);
    }
    // The old files did not change. They moved with the rename.
    expect(File('$oldPath.pre-flutter').readAsBytesSync(), dbBytes);
    expect(File('$oldPath.pre-flutter-journal').readAsBytesSync(), journalBytes);
    expect(Directory('$dir/legacy_import_copy').existsSync(), false);
  });

  test('removes the copy folder when the import from the copy fails', () async {
    changeOld((old) => old.execute('DROP TABLE owed_items'));
    Directory('$oldPath-shm').createSync();
    final r = await run() as ImportFailed;
    expect(r.tables, ['owed_items']);
    expect(Directory('$dir/legacy_import_copy').existsSync(), false);
    expect(File(oldPath).existsSync(), true);
    expect(await prefs.getBool('legacy_import_done'), isNull);
  });

  // Review Focus 2
  test('copies by column name when the old columns are in another order',
      () async {
    changeOld((old) {
      final cols = [
        for (final r in old.select('PRAGMA table_info(expenses)'))
          '"${r['name']}" ${r['type']}',
      ].reversed.toList();
      final names = [for (final c in cols) c.split(' ').first];
      old.execute('CREATE TABLE expenses_new (${cols.join(', ')})');
      old.execute('INSERT INTO expenses_new SELECT ${names.join(', ')} FROM expenses');
      old.execute('DROP TABLE expenses');
      old.execute('ALTER TABLE expenses_new RENAME TO expenses');
      expect(old.select('PRAGMA table_info(expenses)').first['name'],
          'privateToGroups');
    });
    expect(await run(), isA<ImportDone>());
    final e1 = await (newDb.select(newDb.expenses)
          ..where((e) => e.id.equals('e1')))
        .getSingle();
    expect(e1.amount, Decimal.parse('12.50'));
    expect(e1.dedupKey, 'dk-e1');
    expect(e1.notificationKey, 'nk-1');
    expect(e1.categoryId, 'food');
  });

  // Review Focus 4
  test('a second import keeps new rows and lets old rows win on the same key',
      () async {
    const defaults = {
      'food': ('Food', '#E53935'),
      'transport': ('Transport', '#1E88E5'),
      'shopping': ('Shopping', '#8E24AA'),
      'bills': ('Bills & Utilities', '#FB8C00'),
      'entertainment': ('Entertainment', '#43A047'),
      'health': ('Health', '#00ACC1'),
      'other': ('Other', '#757575'),
    };
    for (final e in defaults.entries) {
      await newDb.into(newDb.categories).insert(CategoriesCompanion.insert(
          id: e.key, name: e.value.$1, colorHex: e.value.$2, isDefault: true));
    }
    await newDb.into(newDb.expenses).insert(ExpensesCompanion.insert(
          id: 'new-1',
          amount: Decimal.parse('3.00'),
          currency: 'MYR',
          rawNotificationText: 'raw new-1',
          sourcePackage: 'com.maybank2u.life',
          notificationPostTime: 1763000000000,
          createdAt: 1763000000500,
          dedupKey: 'dk-new-1',
          status: ExpenseStatus.autoSaved,
          confidence: ParseConfidence.high,
          transactionType: TransactionType.withdraw,
          privateToGroups: false,
        ));
    await prefs.setBool('dark_mode', true);

    expect(await run(), isA<ImportDone>());
    expect((await rowCountsOf(newDb))['categories'], 8);
    expect((await rowCountsOf(newDb))['expenses'], 5);
    final food = await (newDb.select(newDb.categories)
          ..where((c) => c.id.equals('food')))
        .getSingle();
    expect(food.name, 'Food & Dining');
    final new1 = await (newDb.select(newDb.expenses)
          ..where((e) => e.id.equals('new-1')))
        .getSingle();
    expect(new1.dedupKey, 'dk-new-1');
    expect(await prefs.getBool('dark_mode'), true);
    expect(await prefs.getBool('onboarding_done'), true);
  });

  // Review Focus 5
  test('rolls back and keeps the old file when a table cannot be copied',
      () async {
    changeOld((old) => old.execute('DROP TABLE owed_items'));
    final r = await run() as ImportFailed;
    expect(r.tables, ['owed_items']);
    expect(r.logLine, startsWith('Data import failed: owed_items ('));
    expect((await rowCountsOf(newDb))['expenses'], 0);
    expect(File('$dir/expense_tracker.db').existsSync(), true);
    expect(File('$dir/expense_tracker.db.pre-flutter').existsSync(), false);
    expect(await prefs.getBool('legacy_import_done'), isNull);
    expect(importFailedMessage,
        'Koban could not move your data. Your data is safe. Update again later.');
  });

  test('refuses an old database that is not version 11', () async {
    changeOld((old) => old.execute('PRAGMA user_version = 10'));
    final r = await run() as ImportFailed;
    expect(r.tables, isEmpty);
    expect(r.detail, 'old database version 10, needs 11');
    expect((await rowCountsOf(newDb))['expenses'], 0);
    expect(File('$dir/expense_tracker.db').existsSync(), true);
  });

  test('skips when there is no old database', () async {
    legacy = FakeLegacySource('$dir/missing/expense_tracker.db');
    expect(await run(), isA<ImportSkipped>());
    expect(await prefs.getKeys(), isEmpty);
  });

  test('returns a failure and keeps the old file when the settings cannot be read',
      () async {
    legacy = FakeLegacySource(oldPath,
        settingsError: PlatformException(code: 'corrupt', message: 'bad file'));
    final r = await run() as ImportFailed;
    expect(r.tables, isEmpty);
    expect(r.detail, contains('bad file'));
    expect((await rowCountsOf(newDb))['expenses'], 0);
    expect(File('$dir/expense_tracker.db').existsSync(), true);
    expect(await prefs.getKeys(), isEmpty);
  });
}
