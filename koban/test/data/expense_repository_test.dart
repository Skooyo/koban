import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/category_repository.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/expense_repository.dart';
import 'package:koban/data/merchant_category_repository.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';

Decimal d(String v) => Decimal.parse(v);

void main() {
  // A Friday. Its week runs from Mon 9 Nov to Sun 15 Nov.
  final now = DateTime(2026, 11, 13, 12);
  final nowMs = now.millisecondsSinceEpoch;
  late KobanDatabase db;
  late ExpenseRepository repo;
  late SplitRepository splits;
  late (int, int) today;

  setUp(() async {
    db = KobanDatabase(NativeDatabase.memory());
    final categories = CategoryRepository(db);
    await categories.seedIfEmpty();
    splits = SplitRepository(db, now: () => nowMs);
    repo = ExpenseRepository(
      db,
      categories: categories,
      merchants: MerchantCategoryRepository(db, now: () => nowMs),
      splits: splits,
      now: () => now,
    );
    today = PeriodCalculator.range(SpendingPeriod.day, anchor: now);
  });
  tearDown(() => db.close());

  int at(
    int y,
    int m,
    int day, [
    int h = 12,
    int min = 0,
    int s = 0,
    int ms = 0,
  ]) => DateTime(y, m, day, h, min, s, ms).millisecondsSinceEpoch;

  Future<void> add(
    String id,
    String amount, {
    TransactionType type = TransactionType.withdraw,
    String? merchant,
    int? postTime,
    String? categoryId,
    String? counted,
    ExpenseStatus status = ExpenseStatus.autoSaved,
  }) => db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: id,
          amount: d(amount),
          currency: 'MYR',
          merchant: Value(merchant),
          rawNotificationText: 'x',
          sourcePackage: 'p',
          notificationPostTime: postTime ?? nowMs,
          createdAt: nowMs,
          dedupKey: id,
          status: status,
          confidence: ParseConfidence.high,
          categoryId: Value(categoryId),
          countedAmount: Value(counted == null ? null : d(counted)),
          transactionType: type,
          privateToGroups: false,
        ),
      );

  Future<Expense> row(String id) => repo.getById(id).then((e) => e!);

  test('totals of text money add up to the cent', () async {
    await add('a', '0.10');
    await add('b', '0.20');
    await add('c', '1234.56');
    await add('r', '50.00', type: TransactionType.receive);

    final total = await repo.watchTotalForRange(today.$1, today.$2).first;
    expect(total, d('1234.86'));
    expect(total.toStringAsFixed(2), '1234.86');
    expect(
      await repo.watchReceivedForRange(today.$1, today.$2).first,
      d('50.00'),
    );
  });

  test('a counted amount replaces the amount in totals', () async {
    await add('a', '24.00', counted: '10.00');

    expect(await repo.watchTotalForRange(today.$1, today.$2).first, d('10.00'));
  });

  test('dismissed payments count nowhere', () async {
    await add('a', '24.00', status: ExpenseStatus.dismissed);

    expect(await repo.watchTotalForRange(today.$1, today.$2).first, d('0'));
    expect(
      await repo.watchCategoryBreakdown(today.$1, today.$2).first,
      isEmpty,
    );
    expect(await repo.watchAllActive().first, isEmpty);
    expect(await repo.watchHasAnyPayment().first, isFalse);
    await add('b', '1.00');
    expect(await repo.watchHasAnyPayment().first, isTrue);
  });

  test(
    'a payment at the last millisecond of a day counts on that day',
    () async {
      await add('last', '7.00', postTime: at(2026, 11, 13, 23, 59, 59, 999));
      await add('next', '3.00', postTime: at(2026, 11, 14, 0));

      final summary = await repo.watchPeriodSummary(SpendingPeriod.day).first;

      expect(summary.total, d('7.00'));
      expect(summary.recentExpenses.map((e) => e.id), ['last']);
      expect(summary.title, 'Today');
      expect(summary.subtitle, 'Fri, 13 Nov 2026');
      expect(summary.periodStart, today.$1);
      expect(summary.periodEnd, today.$2);
    },
  );

  test('the week runs from Monday to Sunday', () async {
    await add('sun', '4.00', postTime: at(2026, 11, 15, 23));
    await add('mon', '8.00', postTime: at(2026, 11, 16, 0));
    await add('before', '2.00', postTime: at(2026, 11, 8, 23, 59, 59, 999));
    await add('start', '1.00', postTime: at(2026, 11, 9, 0));
    await add(
      'in',
      '50.00',
      type: TransactionType.receive,
      postTime: at(2026, 11, 10),
    );

    final week = await repo.watchPeriodSummary(SpendingPeriod.week).first;

    expect(week.title, 'This week');
    expect(week.subtitle, 'Mon 9 Nov – Sun 15 Nov');
    expect(week.total, d('5.00'));
    expect(week.received, d('50.00'));
    expect(week.recentExpenses.map((e) => e.id), ['sun', 'in', 'start']);
  });

  test('month totals group by the local month', () async {
    await add('oct', '10.00', postTime: at(2026, 10, 31, 23, 30));
    await add('nov', '5.00', postTime: at(2026, 11, 1, 0, 10));
    await add(
      'rec',
      '20.00',
      type: TransactionType.receive,
      postTime: at(2026, 11, 2),
    );

    final months = await repo.watchMonthlySummaries().first;

    expect(
      months.map((m) => (m.year, m.month0, m.label, m.total, m.received)),
      [
        (2026, 10, 'November 2026', d('5.00'), d('20.00')),
        (2026, 9, 'October 2026', d('10.00'), d('0')),
      ],
    );
  });

  test('a period summary lists the 5 newest payments', () async {
    for (var h = 1; h <= 6; h++) {
      await add('p$h', '1.00', postTime: at(2026, 11, 13, h));
    }

    final summary = await repo.watchPeriodSummary(SpendingPeriod.month).first;

    expect(summary.recentExpenses.map((e) => e.id), [
      'p6',
      'p5',
      'p4',
      'p3',
      'p2',
    ]);
    expect(summary.total, d('6.00'));
  });

  test(
    'the category breakdown gives names, fractions and Uncategorized',
    () async {
      await add('a', '30.00', categoryId: 'food');
      await add('b', '10.00');

      final rows = await repo.watchCategoryBreakdown(today.$1, today.$2).first;

      expect(
        rows.map(
          (r) => (r.categoryId, r.name, r.colorHex, r.total, r.fraction),
        ),
        [
          ('food', 'Food & Dining', '#E53935', d('30.00'), 0.75),
          (null, 'Uncategorized', '#9E9E9E', d('10.00'), 0.25),
        ],
      );
    },
  );

  test('a category total of 10.00 sorts before one of 9.00 by value', () async {
    await add('a', '9.00', categoryId: 'food');
    await add('b', '10.00', categoryId: 'health');

    final rows = await repo.watchCategoryBreakdown(today.$1, today.$2).first;

    expect(rows.map((r) => r.categoryId), ['health', 'food']);
  });

  test('week summaries of a month are cut to the days of the month', () async {
    await add('first', '3.00', postTime: at(2026, 11, 1, 9));
    await add('second', '4.00', postTime: at(2026, 11, 3, 9));
    await add('last', '5.00', postTime: at(2026, 11, 30, 9));
    await add('october', '6.00', postTime: at(2026, 10, 30, 9));

    final weeks = await repo.weekSummariesForMonth(2026, 10);

    expect(weeks, hasLength(6));
    expect(weeks.first.label, '1 Nov');
    expect(weeks.first.startMs, at(2026, 11, 1, 0));
    expect(weeks.first.endMs, at(2026, 11, 2, 0));
    expect(weeks.last.label, '30 Nov');
    expect(weeks.last.endMs, at(2026, 12, 1, 0));
    expect(weeks.map((w) => w.total), [
      d('3.00'),
      d('4.00'),
      d('0'),
      d('0'),
      d('0'),
      d('5.00'),
    ]);
  });

  test('a new category on an edit applies to past payments from the shop in the same direction', () async {
    await add('w1', '5.00', merchant: 'Kedai Contoh');
    await add('w2', '6.00', merchant: ' kedai contoh ');
    await add(
      'r1',
      '7.00',
      type: TransactionType.receive,
      merchant: 'Kedai Contoh',
    );

    await repo.updateExpense(
      'w1',
      amount: d('5.00'),
      merchant: 'Kedai Contoh',
      postTime: nowMs,
      categoryId: 'food',
      type: TransactionType.withdraw,
    );

    expect((await row('w1')).categoryId, 'food');
    expect((await row('w1')).status, ExpenseStatus.edited);
    expect((await row('w2')).categoryId, 'food');
    expect((await row('r1')).categoryId, isNull);
    final map = await db.select(db.merchantCategoryMap).get();
    expect(
      map.map((m) => (m.merchantKey, m.displayName, m.categoryId, m.updatedAt)),
      [('kedai contoh', 'Kedai Contoh', 'food', nowMs)],
    );
  });

  test('a manual payment has the manual source and key', () async {
    await repo.addManualExpense(
      amount: d('12.5'),
      merchant: '  ',
      postTime: nowMs - 1000,
      notes: ' x ',
      type: TransactionType.withdraw,
    );

    final e = (await db.select(db.expenses).get()).single;
    expect(e.sourcePackage, 'manual');
    expect(e.dedupKey, 'manual:${e.id}');
    expect(e.status, ExpenseStatus.edited);
    expect(e.confidence, ParseConfidence.high);
    expect(e.currency, 'MYR');
    expect(e.merchant, isNull);
    expect(e.notes, 'x');
    expect(e.rawNotificationText, '');
    expect(e.amount, d('12.50'));
    expect(e.notificationPostTime, nowMs - 1000);
    expect(e.createdAt, nowMs);
    expect(e.notificationKey, isNull);
    expect(e.privateToGroups, isFalse);
  });

  SplitDraft debtOfAli({String? linked}) => SplitDraft(
    billId: null,
    merchant: 'RESTORAN CONTOH',
    billTime: nowMs,
    currency: 'MYR',
    printedTotal: null,
    items: [
      DraftItem(
        name: 'Nasi lemak',
        quantity: 1,
        price: d('20.00'),
        sharedBy: {meId, 'draft-ali'},
      ),
      DraftItem(
        name: 'Teh ais',
        quantity: 1,
        price: d('4.00'),
        sharedBy: {'draft-ali'},
      ),
    ],
    charges: SplitCharges(),
    people: [
      SplitPeopleData(
        id: 'draft-ali',
        name: 'Ali',
        lastUsedAt: nowMs,
        archived: false,
      ),
    ],
    linkedExpenseId: linked,
  );

  test(
    'a received manual payment that fits a debt becomes its suggestion',
    () async {
      await splits.saveSplit(debtOfAli());

      await repo.addManualExpense(
        amount: d('14.00'),
        merchant: 'Ali',
        postTime: nowMs,
        type: TransactionType.receive,
      );

      final received = (await db.select(db.expenses).get()).single;
      final debt = (await db.select(db.splitDebts).get()).single;
      expect(debt.amount, d('14.00'));
      expect(debt.suggestedRepaymentExpenseId, received.id);
    },
  );

  test('an edit of a linked payment counts the new share', () async {
    await add('pay', '24.00');
    await splits.saveSplit(debtOfAli(linked: 'pay'));
    expect((await row('pay')).countedAmount, d('10.00'));

    await repo.updateExpense(
      'pay',
      amount: d('30.00'),
      merchant: null,
      postTime: nowMs,
      type: TransactionType.withdraw,
    );

    expect((await row('pay')).countedAmount, d('16.00'));
    expect((await row('pay')).amount, d('30.00'));
  });

  test('delete marks the payment dismissed', () async {
    await add('a', '5.00');

    await repo.dismissExpense('a');
    await repo.dismissExpense('missing');

    expect((await row('a')).status, ExpenseStatus.dismissed);
    expect(await repo.getById('missing'), isNull);
  });

  test('an Error in the split step is logged and the save returns', () async {
    final failing = ExpenseRepository(
      db,
      categories: CategoryRepository(db),
      merchants: MerchantCategoryRepository(db, now: () => nowMs),
      splits: _ThrowingSplits(db, nowMs),
      now: () => now,
    );
    await failing.addManualExpense(
      amount: d('5'),
      postTime: nowMs,
      type: TransactionType.receive,
    );
    final id = (await db.select(db.expenses).get()).single.id;
    await failing.updateExpense(
      id,
      amount: d('6'),
      postTime: nowMs,
      type: TransactionType.receive,
    );
    expect((await db.select(db.expenses).get()).single.amount, d('6'));
  });
}

class _ThrowingSplits extends SplitRepository {
  _ThrowingSplits(super.db, int nowMs) : super(now: () => nowMs);

  @override
  Future<void> onExpenseEdited(String expenseId) async =>
      throw StateError('boom');

  @override
  Future<void> suggestRepayment(Expense receive) async =>
      throw StateError('boom');
}
