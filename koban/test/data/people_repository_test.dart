import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/people_repository.dart';
import 'package:koban/data/qr_store.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/device/device_control.dart';
import 'package:koban/rules/people_math.dart';
import 'package:koban/rules/types.dart';

final T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;

Decimal d(String v) => Decimal.parse(v);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late KobanDatabase db;
  late Directory files;
  late PeopleRepository repo;

  setUp(() {
    db = KobanDatabase(NativeDatabase.memory());
    files = Directory.systemTemp.createTempSync('koban_people');
    final splits = SplitRepository(db, now: () => T);
    repo = PeopleRepository(
      db,
      splits: splits,
      qr: QrStore(filesDir: () async => files, device: DeviceControl()),
      now: () => T,
    );
  });
  tearDown(() async {
    await db.close();
    files.deleteSync(recursive: true);
  });

  Future<SplitPeopleData> person(String id) =>
      (db.select(db.splitPeople)..where((p) => p.id.equals(id))).getSingle();

  Future<void> addExpense(String id, String amount) => db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: id,
          amount: d(amount),
          currency: 'MYR',
          rawNotificationText: 'x',
          sourcePackage: 'p',
          notificationPostTime: T,
          createdAt: T,
          dedupKey: id,
          status: ExpenseStatus.autoSaved,
          confidence: ParseConfidence.high,
          transactionType: TransactionType.receive,
          privateToGroups: false,
        ),
      );

  Future<void> setSuggestion(String personId, String expenseId) =>
      (db.update(db.splitPeople)..where((p) => p.id.equals(personId))).write(
        SplitPeopleCompanion(suggestedSettleExpenseId: Value(expenseId)),
      );

  Future<KobanUserError> refused(Future<void> Function() action) async {
    try {
      await action();
    } on KobanUserError catch (e) {
      return e;
    }
    fail('The action did not throw KobanUserError.');
  }

  test('add person reuses a stored person with the same name and revives an archived one', () async {
    final ali = await repo.addPerson('  Ali ');
    expect((await person(ali)).name, 'Ali');
    expect(await repo.addPerson('ali'), ali);
    expect(await db.select(db.splitPeople).get(), hasLength(1));

    await repo.archivePerson(ali);
    expect((await person(ali)).archived, isTrue);
    expect(await repo.addPerson('ALI'), ali);
    expect((await person(ali)).archived, isFalse);
    expect(await db.select(db.splitPeople).get(), hasLength(1));
  });

  test('a blank name is refused', () async {
    expect(
      (await refused(() => repo.addPerson('   '))).message,
      'Enter a name.',
    );
    final ali = await repo.addPerson('Ali');
    expect(
      (await refused(() => repo.renamePerson(ali, ''))).message,
      'Enter a name.',
    );
  });

  test('rename to a name that someone has is refused', () async {
    final ali = await repo.addPerson('Ali');
    await repo.addPerson('Mei');
    expect(
      (await refused(() => repo.renamePerson(ali, ' mei '))).message,
      'Someone already has that name.',
    );
    await repo.renamePerson(ali, 'Ali Baru');
    expect((await person(ali)).name, 'Ali Baru');
  });

  test('delete with something open is refused', () async {
    final ali = await repo.addPerson('Ali');
    await repo.addOwedItem(ali, 'Teh', d('3.00'), T);
    expect(
      (await refused(() => repo.archivePerson(ali))).message,
      'Settle up with them first.',
    );
    expect((await person(ali)).archived, isFalse);
  });

  test(
    'delete removes paid items and the QR file after the row is cleared',
    () async {
      final ali = await repo.addPerson('Ali');
      await repo.addOwedItem(ali, 'Teh', d('3.00'), T);
      final item = (await db.select(db.owedItems).get()).single;
      await repo.markOwedItemPaid(item.id);
      final qr = File('${files.path}/qr/$ali.img')..createSync(recursive: true);
      await (db.update(db.splitPeople)..where((p) => p.id.equals(ali))).write(
        SplitPeopleCompanion(qrPath: Value(qr.path)),
      );

      await repo.archivePerson(ali);

      final after = await person(ali);
      expect(after.archived, isTrue);
      expect(after.qrPath, isNull);
      expect(await db.select(db.owedItems).get(), isEmpty);
      expect(qr.existsSync(), isFalse);
    },
  );

  test('an owed item needs a reason and an amount above zero', () async {
    final ali = await repo.addPerson('Ali');
    expect(
      (await refused(() => repo.addOwedItem(ali, ' ', d('5.00'), T))).message,
      'Enter what it was for.',
    );
    expect(
      (await refused(() => repo.addOwedItem(ali, 'Teh', d('0'), T))).message,
      'Enter an amount above zero.',
    );
    expect(
      (await refused(() => repo.addOwedToMe(ali, 'Cash', d('-1'), T))).message,
      'Enter an amount above zero.',
    );
    expect(await db.select(db.owedItems).get(), isEmpty);
  });

  test(
    'money owed to me without a bill is a manual split with one open debt',
    () async {
      final ali = await repo.addPerson('Ali');
      await repo.addOwedToMe(ali, ' Cash ', d('20'), T);

      final bill = (await db.select(db.splitBills).get()).single;
      expect(bill.manual, isTrue);
      expect(bill.merchant, 'Cash');
      expect(bill.currency, 'MYR');
      expect(bill.billTime, T);
      final debt = (await db.select(db.splitDebts).get()).single;
      expect(debt.billId, bill.id);
      expect(debt.personId, ali);
      expect(debt.status, DebtStatus.open);
      expect(debt.amount.toStringAsFixed(2), '20.00');

      final detail = await repo.watchPerson(ali).first;
      expect(detail!.balance, PaysYou(d('20.00')));
      expect(detail.owedToMe.single.manual, isTrue);
    },
  );

  test(
    'an edit of money owed to me drops a repayment suggestion that included it',
    () async {
      final ali = await repo.addPerson('Ali');
      await repo.addOwedToMe(ali, 'Cash', d('20'), T);
      await repo.addOwedToMe(ali, 'Lunch', d('5'), T);
      await addExpense('r1', '25.00');
      await db
          .update(db.splitDebts)
          .write(
            const SplitDebtsCompanion(suggestedRepaymentExpenseId: Value('r1')),
          );
      final cash = (await db.select(db.splitBills).get()).firstWhere(
        (b) => b.merchant == 'Cash',
      );
      final debt = (await db.select(db.splitDebts).get()).firstWhere(
        (x) => x.billId == cash.id,
      );

      await repo.updateOwedToMe(debt.id, 'Cash back', d('30'), T + 1);

      final debts = await db.select(db.splitDebts).get();
      expect(debts.map((x) => x.suggestedRepaymentExpenseId), [null, null]);
      final edited = debts.firstWhere((x) => x.id == debt.id);
      expect(edited.amount.toStringAsFixed(2), '30.00');
      final bills = await db.select(db.splitBills).get();
      expect(bills.map((b) => b.merchant), containsAll(['Cash back', 'Lunch']));
    },
  );

  test('settle up closes every debt and every item of the person', () async {
    final ali = await repo.addPerson('Ali');
    await repo.addOwedToMe(ali, 'Cash', d('20'), T);
    await repo.addOwedItem(ali, 'Teh', d('3.00'), T);

    await repo.settleUp(ali);

    final debt = (await db.select(db.splitDebts).get()).single;
    expect(debt.status, DebtStatus.paid);
    expect(debt.paidAt, T);
    final item = (await db.select(db.owedItems).get()).single;
    expect(item.status, DebtStatus.paid);
    expect(item.paidAt, T);
    expect((await repo.watchPerson(ali).first)!.balance, const AllPaid());
  });

  test('a stale settle suggestion is cleared and settles nothing', () async {
    final ali = await repo.addPerson('Ali');
    await repo.addOwedToMe(ali, 'Cash', d('20'), T);
    await addExpense('r1', '99.00');
    await setSuggestion(ali, 'r1');

    expect(await repo.confirmSettleSuggestion(ali), isFalse);

    expect((await person(ali)).suggestedSettleExpenseId, isNull);
    expect(
      (await db.select(db.splitDebts).get()).single.status,
      DebtStatus.open,
    );
  });

  test(
    'a settle suggestion that matches the net settles up and links the payment',
    () async {
      final ali = await repo.addPerson('Ali');
      await repo.addOwedToMe(ali, 'Cash', d('20'), T);
      await addExpense('r1', '20.00');
      await setSuggestion(ali, 'r1');

      expect(await repo.confirmSettleSuggestion(ali), isTrue);

      final debt = (await db.select(db.splitDebts).get()).single;
      expect(debt.status, DebtStatus.paid);
      expect(debt.repaymentExpenseId, 'r1');
      expect((await person(ali)).suggestedSettleExpenseId, isNull);
    },
  );
}
