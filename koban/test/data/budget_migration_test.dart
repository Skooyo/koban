import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/budget_repository.dart';
import 'package:koban/data/database.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_db.dart';

Future<int> userVersion(KobanDatabase db) async =>
    (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
      'user_version',
    );

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test(
    'upgrade from a version 1 file keeps every row and adds budget_limits',
    () async {
      final dir = Directory.systemTemp.createTempSync('koban_v1_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/koban.sqlite';

      // A version 1 file: the 11 tables with the 31 fixture rows, no budget_limits.
      File('test/fixtures/room_v11.db').copySync(path);
      final v1 = sqlite3.open(path);
      v1.execute('PRAGMA journal_mode = DELETE');
      v1.execute('PRAGMA user_version = 1');
      expect(
        v1.select(
          "SELECT name FROM sqlite_master WHERE name = 'budget_limits'",
        ),
        isEmpty,
      );
      expect(rowCounts(v1), fixtureCounts);
      final rowsBefore = {
        for (final t in fixtureCounts.keys)
          t: v1.select('SELECT * FROM $t').rows,
      };
      v1.close();

      final db = KobanDatabase(NativeDatabase(File(path)));
      addTearDown(db.close);
      // The first query runs the upgrade.
      expect(await rowCountsOf(db), fixtureCounts);
      for (final t in fixtureCounts.keys) {
        final rows = [
          for (final r in await db.customSelect('SELECT * FROM $t').get())
            r.data.values.toList(),
        ];
        expect(rows, rowsBefore[t], reason: t);
      }
      expect(await userVersion(db), 2);

      // The new table works on the upgraded file.
      final repo = BudgetRepository(db, now: () => DateTime.utc(2026, 11, 20));
      await repo.setLimit('food', Decimal.parse('100'));
      expect((await repo.getMonth()).totalLimit, Decimal.parse('100'));
    },
  );

  test('a new database starts at version 2 with the table', () async {
    final db = KobanDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await userVersion(db), 2);
    expect(await db.allLimitRows('MYR').get(), isEmpty);
  });
}
