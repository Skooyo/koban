import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';

final T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;
const hour = 3600000;
const day = 86400000;

Decimal d(String v) => Decimal.parse(v);

void main() {
  late KobanDatabase db;
  late SplitRepository repo;

  setUp(() {
    db = KobanDatabase(NativeDatabase.memory());
    repo = SplitRepository(db, now: () => T);
  });
  tearDown(() => db.close());

  Future<void> addExpense(
    String id,
    String amount, {
    TransactionType type = TransactionType.withdraw,
    String? merchant,
    int? postTime,
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
          notificationPostTime: postTime ?? T,
          createdAt: T,
          dedupKey: id,
          status: ExpenseStatus.autoSaved,
          confidence: ParseConfidence.high,
          transactionType: type,
          privateToGroups: false,
        ),
      );

  Future<void> addPerson(String id, String name, {bool archived = false}) => db
      .into(db.splitPeople)
      .insert(
        SplitPeopleCompanion.insert(
          id: id,
          name: name,
          lastUsedAt: T - 1000,
          archived: Value(archived),
        ),
      );

  SplitPeopleData draftAli([String name = 'Ali']) => SplitPeopleData(
    id: 'draft-ali',
    name: name,
    lastUsedAt: T,
    archived: false,
  );

  // Draft A: Ali owes 14.00.
  SplitDraft draftA({
    String? billId,
    String? linked,
    String personName = 'Ali',
    List<DraftItem>? items,
  }) => SplitDraft(
    billId: billId,
    merchant: 'RESTORAN CONTOH',
    billTime: T,
    currency: 'MYR',
    printedTotal: null,
    items:
        items ??
        [
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
    people: [draftAli(personName)],
    linkedExpenseId: linked,
  );

  // A second bill: Ali owes 5.00 more.
  SplitDraft draftB() => draftA(
    items: [
      DraftItem(
        name: 'Roti',
        quantity: 1,
        price: d('5.00'),
        sharedBy: {'draft-ali'},
      ),
    ],
  );

  Future<List<SplitDebt>> debts() => db.select(db.splitDebts).get();
  Future<Expense> expense(String id) =>
      (db.select(db.expenses)..where((e) => e.id.equals(id))).getSingle();
  Future<SplitPeopleData> person(String id) =>
      (db.select(db.splitPeople)..where((p) => p.id.equals(id))).getSingle();

  test('recent items rank the shop first, give the last unit price and skip made lines', () async {
    DraftItem item(String name, int qty, String price) =>
        DraftItem(name: name, quantity: qty, price: d(price), sharedBy: {meId});
    SplitDraft bill(String shop, int time, List<DraftItem> items) => SplitDraft(
      billId: null,
      merchant: shop,
      billTime: time,
      currency: 'MYR',
      printedTotal: null,
      items: items,
      charges: SplitCharges(),
      people: const [],
      linkedExpenseId: null,
    );
    await repo.saveSplit(
      bill('Pelita', T - day, [
        item('Teh tarik', 3, '8.10'),
        item('Roti canai', 2, '3.20'),
      ]),
    );
    await repo.saveSplit(
      bill('Kedai Lain', T, [
        item('Teh tarik', 1, '3.00'),
        item('Kopi', 1, '2.50'),
        item(restItemName, 1, '9.00'),
        item('Kedai Lain', 1, '4.00'),
        item('Kedai Lain · Ali', 1, '1.00'),
      ]),
    );
    final recent = await repo.recentItems();
    List<(String, Decimal)> names(List<RecentItem> l) => [
      for (final i in l) (i.name, i.unitPrice),
    ];

    expect(names(rankRecentItems(recent, ' pelita ')), [
      ('Teh tarik', d('2.70')),
      ('Roti canai', d('1.60')),
      ('Kopi', d('2.50')),
    ]);
    expect(names(rankRecentItems(recent, null)), [
      ('Teh tarik', d('3.00')),
      ('Kopi', d('2.50')),
      ('Roti canai', d('1.60')),
    ]);
  });

  test('a saved split makes one open debt for each other person', () async {
    final billId = await repo.saveSplit(draftA());

    final rows = await debts();
    expect(rows, hasLength(1));
    final ali = (await db.select(db.splitPeople).get()).single;
    expect(ali.name, 'Ali');
    expect(rows.single.personId, ali.id);
    expect(rows.single.amount, d('14.00'));
    expect(rows.single.status, DebtStatus.open);
    final items =
        await (db.select(db.splitItems)
              ..where((i) => i.billId.equals(billId))
              ..orderBy([(i) => OrderingTerm.asc(i.position)]))
            .get();
    expect(items.map((i) => i.position), [0, 1]);
    final stored = await db.select(db.splitBills).getSingle();
    expect(stored.id, billId);
    expect(stored.serviceCharge, d('0.00'));
  });

  test('a draft person with the same name in other case reuses the stored person and revives them', () async {
    await addPerson('s1', 'Ali', archived: true);

    await repo.saveSplit(draftA(personName: ' ali '));

    expect(await db.select(db.splitPeople).get(), hasLength(1));
    final ali = await person('s1');
    expect(ali.archived, false);
    expect(ali.lastUsedAt, T);
    expect((await debts()).single.personId, 's1');
  });

  test('a split with a paid debt cannot change', () async {
    final billId = await repo.saveSplit(draftA());
    await repo.markPaid((await debts()).single.id, null);

    await expectLater(
      repo.saveSplit(draftA(billId: billId)),
      throwsA(
        isA<KobanUserError>().having(
          (e) => e.message,
          'message',
          "This split already has a repayment, so it can't change.",
        ),
      ),
    );
    expect(await repo.isLocked(billId), true);
  });

  test('a linked payment counts only the share of the owner', () async {
    await addExpense('w1', '24.00');
    final billId = await repo.saveSplit(draftA());

    await repo.linkPayment(billId, 'w1');
    expect((await expense('w1')).countedAmount, d('10.00'));
    expect((await repo.billForExpense('w1'))!.id, billId);

    await repo.linkPayment(billId, null);
    expect((await expense('w1')).countedAmount, isNull);
    expect(await repo.billForExpense('w1'), isNull);
  });

  test('a payment that belongs to another split is refused', () async {
    await addExpense('w1', '24.00');
    final first = await repo.saveSplit(draftA(linked: 'w1'));
    final second = await repo.saveSplit(draftB());

    await expectLater(
      repo.linkPayment(second, 'w1'),
      throwsA(
        isA<KobanUserError>().having(
          (e) => e.message,
          'message',
          'This payment already belongs to another split.',
        ),
      ),
    );
    expect((await repo.billForExpense('w1'))!.id, first);
  });

  test('an edit of the linked payment counts the new share', () async {
    await addExpense('w1', '24.00');
    await repo.saveSplit(draftA(linked: 'w1'));
    expect((await expense('w1')).countedAmount, d('10.00'));

    await (db.update(db.expenses)..where((e) => e.id.equals('w1'))).write(
      ExpensesCompanion(amount: Value(d('30.00'))),
    );
    await repo.onExpenseEdited('w1');

    expect((await expense('w1')).countedAmount, d('16.00'));
  });

  test('delete split frees the linked payment and a repayment that pays nothing else', () async {
    await addExpense('w1', '24.00');
    await addExpense('r1', '19.00', type: TransactionType.receive);
    final a = await repo.saveSplit(draftA(linked: 'w1'));
    final b = await repo.saveSplit(draftB());
    final debtA = (await debts()).firstWhere((x) => x.billId == a);
    await repo.markPaid(debtA.id, 'r1');
    expect((await expense('r1')).countedAmount, d('0.00'));

    await repo.deleteSplit(a);
    expect((await expense('w1')).countedAmount, isNull);
    // The repayment still pays the debt of the other split.
    expect((await expense('r1')).countedAmount, d('0.00'));
    expect((await debts()).map((x) => x.billId), [b]);

    await repo.deleteSplit(b);
    expect((await expense('r1')).countedAmount, isNull);
    expect(await debts(), isEmpty);
    expect(await db.select(db.splitBills).get(), isEmpty);
    expect(await db.select(db.splitItems).get(), isEmpty);
    expect(await db.select(db.splitItemShares).get(), isEmpty);
  });

  test('payment candidates are unlinked spends within 3 days with the exact amount first', () async {
    await addExpense('far', '24.00', postTime: T - 4 * day);
    await addExpense('other', '10.00', postTime: T - 2 * hour);
    await addExpense('exact', '24.00', postTime: T - hour);
    await addExpense(
      'recv',
      '24.00',
      type: TransactionType.receive,
      postTime: T - hour,
    );

    final list = await repo.paymentCandidates(null, d('24.00'), T);

    expect(list.map((e) => e.id), ['exact', 'other']);
  });

  test('mark paid with the whole open amount of the person closes every debt of the person', () async {
    await addExpense('r1', '19.00', type: TransactionType.receive);
    final a = await repo.saveSplit(draftA());
    await repo.saveSplit(draftB());
    final debtA = (await debts()).firstWhere((x) => x.billId == a);

    await repo.markPaid(debtA.id, 'r1');

    final rows = await debts();
    expect(rows.map((x) => x.status), [DebtStatus.paid, DebtStatus.paid]);
    expect(rows.map((x) => x.repaymentExpenseId), ['r1', 'r1']);
    expect(rows.map((x) => x.paidAt), [T, T]);
    expect((await expense('r1')).countedAmount, d('0.00'));
  });

  test('mark paid with another amount is refused', () async {
    await addExpense('r1', '10.00', type: TransactionType.receive);
    await repo.saveSplit(draftA());
    final debtId = (await debts()).single.id;

    await expectLater(
      repo.markPaid(debtId, 'r1'),
      throwsA(
        isA<KobanUserError>().having(
          (e) => e.message,
          'message',
          'Repayment amount does not match this debt',
        ),
      ),
    );
    expect((await debts()).single.status, DebtStatus.open);
  });

  test('a receive that fits open debts becomes their suggestion', () async {
    await repo.saveSplit(draftA());
    await addExpense(
      'r1',
      '14.00',
      type: TransactionType.receive,
      merchant: 'ALI',
    );

    await repo.suggestRepayment(await expense('r1'));

    expect((await debts()).single.suggestedRepaymentExpenseId, 'r1');
  });

  test(
    'a receive that fits no debt set suggests a settle up for one person',
    () async {
      await repo.saveSplit(draftA());
      final ali = (await db.select(db.splitPeople).get()).single;
      await db
          .into(db.owedItems)
          .insert(
            OwedItemsCompanion.insert(
              id: 'o1',
              personId: ali.id,
              description: 'Kopi',
              amount: d('4.00'),
              itemDate: T,
              createdAt: T,
              status: DebtStatus.open,
            ),
          );
      await addExpense(
        'r1',
        '10.00',
        type: TransactionType.receive,
        merchant: 'ALI',
      );

      await repo.suggestRepayment(await expense('r1'));

      expect((await person(ali.id)).suggestedSettleExpenseId, 'r1');
      expect((await debts()).single.suggestedRepaymentExpenseId, isNull);
    },
  );

  test('a stale suggestion is cleared and closes nothing', () async {
    await repo.saveSplit(draftA());
    await addExpense(
      'r1',
      '14.00',
      type: TransactionType.receive,
      merchant: 'ALI',
    );
    await repo.suggestRepayment(await expense('r1'));
    await (db.update(db.expenses)..where((e) => e.id.equals('r1'))).write(
      ExpensesCompanion(amount: Value(d('13.00'))),
    );
    final debtId = (await debts()).single.id;

    await repo.confirmSuggestion(debtId);

    final debt = (await debts()).single;
    expect(debt.status, DebtStatus.open);
    expect(debt.suggestedRepaymentExpenseId, isNull);
    expect((await expense('r1')).countedAmount, isNull);
  });

  group('watchOpenDebts emits again after a write to', () {
    Future<void> check(
      Future<void> Function(String debtId, String personId, String billId)
      write,
      bool Function(OpenDebtView v) changed,
    ) async {
      final billId = await repo.saveSplit(draftA());
      final debt = (await debts()).single;
      final seen = <List<OpenDebtView>>[];
      final sub = repo.watchOpenDebts().listen(seen.add);
      Future<void> until(int n) async {
        for (var i = 0; i < 100 && seen.length < n; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      await until(1);
      expect(seen.first.single.debt.amount, d('14.00'));
      expect(seen.first.single.personName, 'Ali');
      expect(seen.first.single.billMerchant, 'RESTORAN CONTOH');

      await write(debt.id, debt.personId, billId);
      await until(2);
      await sub.cancel();

      expect(seen.last.map(changed), [true]);
    }

    test('the debts table', () async {
      await check(
        (debtId, _, _) =>
            (db.update(db.splitDebts)..where((x) => x.id.equals(debtId))).write(
              SplitDebtsCompanion(amount: Value(d('9.00'))),
            ),
        (v) => v.debt.amount == d('9.00'),
      );
    });

    test('the people table', () async {
      await check(
        (_, personId, _) =>
            (db.update(db.splitPeople)..where((x) => x.id.equals(personId)))
                .write(const SplitPeopleCompanion(name: Value('Mei'))),
        (v) => v.personName == 'Mei',
      );
    });

    test('the bills table', () async {
      await check(
        (_, _, billId) =>
            (db.update(db.splitBills)..where((x) => x.id.equals(billId))).write(
              const SplitBillsCompanion(merchant: Value('Kedai Contoh')),
            ),
        (v) => v.billMerchant == 'Kedai Contoh',
      );
    });
  });
}
