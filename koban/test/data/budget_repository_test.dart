import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/budget_repository.dart';
import 'package:koban/data/category_repository.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/rules/types.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  late KobanDatabase db;
  late BudgetRepository repo;
  late CategoryRepository categories;
  // 20 November 2026, 10:00 in Malaysia.
  var clock = DateTime.utc(2026, 11, 20, 2);

  setUp(() async {
    clock = DateTime.utc(2026, 11, 20, 2);
    db = KobanDatabase(NativeDatabase.memory());
    repo = BudgetRepository(db, now: () => clock);
    categories = CategoryRepository(db);
    await categories.seedIfEmpty();
  });
  tearDown(() => db.close());

  var n = 0;
  Future<void> pay(
    String amount, {
    String? category = 'food',
    String currency = 'MYR',
    TransactionType type = TransactionType.withdraw,
    ExpenseStatus status = ExpenseStatus.autoSaved,
    String? counted,
    required DateTime at,
  }) => db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: 'e${n++}',
          amount: d(amount),
          currency: currency,
          rawNotificationText: 'raw',
          sourcePackage: 'pkg',
          notificationPostTime: at.millisecondsSinceEpoch,
          createdAt: 0,
          dedupKey: 'k$n',
          status: status,
          confidence: ParseConfidence.high,
          transactionType: type,
          privateToGroups: false,
          categoryId: Value(category),
          countedAmount: Value(counted == null ? null : d(counted)),
        ),
      );

  final inNov = DateTime.utc(2026, 11, 10, 4);

  test('the month follows Malaysia time, not UTC', () {
    clock = DateTime.utc(2026, 10, 31, 16); // 1 Nov 00:00 in Malaysia
    expect(repo.currentMonth, const YearMonth(2026, 11));
    clock = DateTime.utc(2026, 10, 31, 15, 59); // 31 Oct 23:59 in Malaysia
    expect(repo.currentMonth, const YearMonth(2026, 10));
  });

  test(
    'a limit counts the whole month and past months keep the old one',
    () async {
      // Spent on 2 Nov, limit set on 20 Nov: the whole of November counts.
      await pay('90.00', at: DateTime.utc(2026, 11, 2, 4));
      await repo.setLimit('food', d('100'));
      final m = await repo.getMonth();
      expect(m.items.single.limit, d('100'));
      expect(m.items.single.spent, d('90'));

      // The limit does not exist before the month it starts in.
      expect((await repo.getMonth(const YearMonth(2026, 10))).items, isEmpty);

      // December: change the limit. November keeps 100.
      clock = DateTime.utc(2026, 12, 5, 4);
      await repo.setLimit('food', d('250'));
      expect((await repo.getMonth()).items.single.limit, d('250'));
      expect(
        (await repo.getMonth(const YearMonth(2026, 11))).items.single.limit,
        d('100'),
      );

      // January: remove it. December keeps 250, January has none.
      clock = DateTime.utc(2027, 1, 5, 4);
      await repo.clearLimit('food');
      expect((await repo.getMonth()).items, isEmpty);
      expect(
        (await repo.getMonth(const YearMonth(2026, 12))).items.single.limit,
        d('250'),
      );
      expect(await db.allLimitRows('MYR').get(), hasLength(3));
    },
  );

  test(
    'a change in the same month replaces that month, with one row',
    () async {
      await repo.setLimit('food', d('100'));
      await repo.setLimit('food', d('150.5'));
      final rows = await db.allLimitRows('MYR').get();
      expect(rows.map((r) => (r.startMonth, r.amount)), [
        ('2026-11', d('150.5')),
      ]);
    },
  );

  test(
    'a removal with no older limit leaves no row; zero removes too',
    () async {
      await repo.setLimit('food', d('100'));
      await repo.clearLimit('food');
      expect(await db.allLimitRows('MYR').get(), isEmpty);
      await repo.setLimit('food', d('100'));
      await repo.setLimit('food', Decimal.zero);
      expect(await db.allLimitRows('MYR').get(), isEmpty);
    },
  );

  test(
    'spent counts MYR money out, my share of a split, not RECEIVE or DISMISSED',
    () async {
      await repo.setLimit('food', d('500'));
      await pay('10.00', at: inNov);
      await pay('50.00', counted: '12.50', at: inNov); // my share of a split
      await pay('99.00', currency: 'IDR', at: inNov);
      await pay('77.00', type: TransactionType.receive, at: inNov);
      await pay('66.00', status: ExpenseStatus.dismissed, at: inNov);
      await pay('55.00', at: DateTime.utc(2026, 10, 31, 15, 59)); // October
      await pay('44.00', at: DateTime.utc(2026, 11, 30, 16)); // December
      await pay('33.00', category: 'transport', at: inNov); // no limit
      await pay('22.00', category: null, at: inNov); // Uncategorized
      final m = await repo.getMonth();
      expect(m.items.single.spent, d('22.50'));
      expect(m.totalLimit, d('500'));
      expect(m.totalSpent, d('22.50'));
    },
  );

  test('state is under below 80%, warn from 80%, over from 100%', () async {
    await repo.setLimit('food', d('100'));
    Future<(BudgetState, Decimal)> at(String amount) async {
      await db.delete(db.expenses).go();
      await pay(amount, at: inNov);
      final i = (await repo.getMonth()).items.single;
      return (i.state, i.over);
    }

    expect(await at('79.99'), (BudgetState.under, Decimal.zero));
    expect(await at('80.00'), (BudgetState.warn, Decimal.zero));
    expect(await at('99.99'), (BudgetState.warn, Decimal.zero));
    expect(await at('100.00'), (BudgetState.over, Decimal.zero));
    expect(await at('130.25'), (BudgetState.over, d('30.25')));
  });

  test(
    'the summary has the total of limits, the over count and name order',
    () async {
      await repo.setLimit('transport', d('200'));
      await repo.setLimit('food', d('100'));
      await repo.setLimit('health', d('50'));
      await pay('120.00', at: inNov); // food: over
      await pay('50.00', category: 'health', at: inNov); // health: over
      await pay('10.00', category: 'transport', at: inNov);
      final m = await repo.getMonth();
      expect(m.items.map((i) => i.category.id), [
        'food',
        'health',
        'transport',
      ]);
      expect(m.totalLimit, d('350'));
      expect(m.overCount, 2);
    },
  );

  test(
    'the stream emits again after a payment and after a limit change',
    () async {
      final seen = <(Decimal, Decimal)>[];
      final sub = repo.watchMonth().listen(
        (m) => seen.add((m.totalLimit, m.totalSpent)),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();
      await repo.setLimit('food', d('100'));
      await pumpEventQueue();
      await pay('30.00', at: inNov);
      await pumpEventQueue();
      await repo.setLimit('food', d('120'));
      await pumpEventQueue();
      expect(seen.last, (d('120'), d('30')));
      expect(
        seen,
        containsAllInOrder([
          (d('100'), d('0')),
          (d('100'), d('30')),
          (d('120'), d('30')),
        ]),
      );
      expect(await repo.watchLimits().first, {'food': d('120')});
    },
  );

  test(
    'deleting a category deletes its limits and Undo brings them back',
    () async {
      await categories.addCategory('Hobi', '#123456');
      final hobi = (await categories.getAll()).firstWhere(
        (c) => c.name == 'Hobi',
      );
      await repo.setLimit(hobi.id, d('80'));
      await repo.setLimit('food', d('100'));
      clock = DateTime.utc(2026, 12, 5, 4);
      await repo.setLimit(hobi.id, d('90'));
      final before = await db.limitRowsOfCategory(hobi.id).get();
      expect(before, hasLength(2));

      final undo = await categories.deleteCategory(hobi.id);
      expect(await db.limitRowsOfCategory(hobi.id).get(), isEmpty);
      expect((await repo.getMonth()).items.map((i) => i.category.id), ['food']);

      await undo!.undo();
      final after = await db.limitRowsOfCategory(hobi.id).get();
      expect(after.toSet(), before.toSet());
      expect((await repo.getMonth()).items.map((i) => i.category.id), [
        'food',
        hobi.id,
      ]);
      // The limit of another category was never touched.
      expect(await db.limitRowsOfCategory('food').get(), hasLength(1));
    },
  );

  test(
    'a built-in category keeps its limit when the delete is refused',
    () async {
      await repo.setLimit('food', d('100'));
      expect(await categories.deleteCategory('food'), isNull);
      expect(await db.limitRowsOfCategory('food').get(), hasLength(1));
    },
  );
}
