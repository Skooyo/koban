import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/watch.dart';

void main() {
  late KobanDatabase db;

  setUp(() => db = KobanDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> addCategory(String id) => db
      .into(db.categories)
      .insert(
        CategoriesCompanion.insert(
          id: id,
          name: id,
          colorHex: '#000000',
          isDefault: false,
        ),
      );

  test(
    'a write while the first load runs makes the stream emit again',
    () async {
      final gate = Completer<void>();
      final firstLoadRead = Completer<void>();
      var calls = 0;
      final stream = watchTables(db, {db.categories}, () async {
        final count = (await db.select(db.categories).get()).length;
        if (calls++ == 0) {
          firstLoadRead.complete();
          await gate.future;
        }
        return count;
      });
      final emitted = stream.take(2).toList();

      await firstLoadRead.future;
      await addCategory('a');
      gate.complete();

      expect(await emitted, [0, 1]);
    },
  );

  test('a cancelled stream stops its loads', () async {
    var calls = 0;
    final stream = watchTables(db, {db.categories}, () async => calls++);
    expect(await stream.first, 0);

    await addCategory('a');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(calls, 1);
  });

  test('each write to a watched table emits one more value', () async {
    final seen = <int>[];
    final sub = watchTables(
      db,
      {db.categories},
      () async => (await db.select(db.categories).get()).length,
    ).listen(seen.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await addCategory('a');
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await (db.update(db.categories))
        .write(const CategoriesCompanion(name: Value('b')));
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await sub.cancel();

    expect(seen, [0, 1, 1]);
  });
}
