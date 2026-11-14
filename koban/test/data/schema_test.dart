import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/types.dart';
import 'package:sqlite3/sqlite3.dart';

/// The user tables of a file, sorted. Room and SQLite own tables are not counted.
List<String> userTables(Database db) => [
      for (final r in db.select(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' AND name NOT IN ('android_metadata', 'room_master_table') "
          'ORDER BY name'))
        r['name'] as String,
    ];

/// The rows of PRAGMA table_info for one table, as plain lists.
List<List<Object?>> tableInfo(Database db, String t) => [
      for (final r in db.select('PRAGMA table_info(`$t`)'))
        [r['cid'], r['name'], r['type'], r['notnull'], r['dflt_value'], r['pk']],
    ];

/// Each index of one table: name, unique flag and columns, sorted by name.
List<List<Object?>> indexes(Database db, String t) {
  final list = [
    for (final r in db.select('PRAGMA index_list(`$t`)'))
      if ((r['origin'] as String) == 'c')
        [
          r['name'],
          r['unique'],
          [
            for (final c in db.select('PRAGMA index_info(`${r['name']}`)'))
              c['name'],
          ],
        ],
  ];
  list.sort((a, b) => (a[0] as String).compareTo(b[0] as String));
  return list;
}

void main() {
  late Database fixture;
  late KobanDatabase newDb;
  // The Drift database runs on a second connection. It is opened by a query.
  late Database fresh;

  setUp(() async {
    fixture =
        sqlite3.open('test/fixtures/room_v11.db', mode: OpenMode.readOnly);
    newDb = KobanDatabase(NativeDatabase.memory());
    await newDb.customSelect('SELECT 1').get();
    fresh = await _freshCopy(newDb);
  });
  tearDown(() async {
    fixture.close();
    fresh.close();
    await newDb.close();
  });

  test('the new database has exactly the 11 Room tables', () {
    expect(userTables(fresh), userTables(fixture));
    expect(userTables(fixture).length, 11);
  });

  test('every table has the same columns as Room version 11', () {
    for (final t in legacyTableOrder) {
      expect(tableInfo(fresh, t), tableInfo(fixture, t), reason: t);
    }
  });

  test('every index matches Room version 11', () {
    for (final t in legacyTableOrder) {
      expect(indexes(fresh, t), indexes(fixture, t), reason: t);
    }
  });

  test('stored values use the Room formats', () async {
    await newDb.into(newDb.expenses).insert(ExpensesCompanion.insert(
          id: 'x1',
          amount: Decimal.parse('12.5'),
          currency: 'IDR',
          rawNotificationText: 'raw',
          sourcePackage: 'pkg',
          notificationPostTime: 1,
          createdAt: 2,
          dedupKey: 'k1',
          status: ExpenseStatus.edited,
          confidence: ParseConfidence.high,
          transactionType: TransactionType.withdraw,
          privateToGroups: true,
          countedAmount: const Value(null),
        ));
    final row = await newDb
        .customSelect(
            'SELECT amount, status, transactionType, privateToGroups, countedAmount FROM expenses')
        .getSingle();
    expect(row.data, {
      'amount': '12.50',
      'status': 'EDITED',
      'transactionType': 'WITHDRAW',
      'privateToGroups': 1,
      'countedAmount': null,
    });
  });
}

/// Copy the schema of [db] into a plain sqlite3 connection so the tests can run PRAGMA calls.
Future<Database> _freshCopy(KobanDatabase db) async {
  final copy = sqlite3.openInMemory();
  final rows = await db
      .customSelect(
          "SELECT sql FROM sqlite_master WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%' ORDER BY type DESC")
      .get();
  for (final r in rows) {
    copy.execute(r.read<String>('sql'));
  }
  return copy;
}
