import 'package:koban/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

/// The row count of each table in the test fixture (31 rows).
const Map<String, int> fixtureCounts = {
  'expenses': 4,
  'categories': 8,
  'merchant_category_map': 2,
  'pending_payments': 2,
  'dropped_notifications': 2,
  'split_bills': 2,
  'split_items': 2,
  'split_people': 2,
  'split_item_shares': 3,
  'split_debts': 2,
  'owed_items': 2,
};

/// Count the rows of every table in [fixtureCounts].
Map<String, int> rowCounts(Database db) => {
      for (final table in fixtureCounts.keys)
        table: db.select('SELECT COUNT(*) FROM $table').first.columnAt(0) as int,
    };

/// The distinct values of one column, sorted.
List<Object?> distinct(Database db, String table, String column) => [
      for (final row in db.select(
          'SELECT DISTINCT $column AS v FROM $table ORDER BY v'))
        row['v'],
    ];

/// Count the rows of every table in [fixtureCounts] in a Drift database.
Future<Map<String, int>> rowCountsOf(KobanDatabase db) async => {
      for (final table in fixtureCounts.keys)
        table: (await db.customSelect('SELECT COUNT(*) AS c FROM $table').getSingle())
            .read<int>('c'),
    };
