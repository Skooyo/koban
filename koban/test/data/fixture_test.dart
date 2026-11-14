import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'test_db.dart';

void main() {
  late Database db;
  setUp(() => db = sqlite3.open('test/fixtures/room_v11.db', mode: OpenMode.readOnly));
  tearDown(() => db.close());

  test('the fixture is a Room version 11 file with every table filled', () {
    expect(db.select('PRAGMA user_version').first.columnAt(0), 11);
    expect(rowCounts(db), fixtureCounts);
  });

  test('the fixture holds every enum value', () {
    expect(distinct(db, 'expenses', 'status'), ['AUTO_SAVED', 'DISMISSED', 'EDITED']);
    expect(distinct(db, 'expenses', 'confidence'), ['HIGH', 'LOW', 'MEDIUM']);
    expect(distinct(db, 'expenses', 'transactionType'), ['RECEIVE', 'WITHDRAW']);
    expect(distinct(db, 'pending_payments', 'format'), ['KNOWN', 'UNKNOWN']);
    expect(distinct(db, 'split_debts', 'status'), ['OPEN', 'PAID']);
    expect(distinct(db, 'owed_items', 'status'), ['OPEN', 'PAID']);
    expect(db.select("SELECT amount FROM expenses WHERE id = 'e1'").first['amount'], '12.50');
  });
}
