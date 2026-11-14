import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/category_repository.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/expense_repository.dart';
import 'package:koban/data/merchant_category_repository.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/data/payment_checks.dart';
import 'package:koban/data/pending_payment_repository.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/dedup_key_generator.dart';
import 'package:koban/rules/parsed_expense.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';

const maybank = 'com.maybank2u.life';
const qrText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
final T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;
final P = T - 60000;

/// Drift streams do not run under fakeAsync without a new package, so the
/// tests use real time. The window is long, so a slow test run cannot end it:
/// the tests end it with flushHold. Only the timer test uses [timerHold].
const longHold = Duration(minutes: 1);
const timerHold = Duration(milliseconds: 500);

Decimal d(String v) => Decimal.parse(v);

ParsedExpense parsed(
  String amount,
  String? merchant, {
  TransactionType type = TransactionType.withdraw,
}) => ParsedExpense(
  amount: d(amount),
  currency: 'MYR',
  merchant: merchant,
  confidence: ParseConfidence.high,
  transactionType: type,
  directionClear: true,
);

void main() {
  late KobanDatabase db;
  late PendingPaymentRepository pending;
  late MerchantCategoryRepository merchants;
  late SplitRepository splits;
  late PaymentChecks checks;
  late List<ConfirmResult> results;
  late ExpenseRepository expenses;

  /// Makes [checks] with [hold] and records its results in [results].
  void useChecks(Duration hold) {
    checks = PaymentChecks(
      db: db,
      pending: pending,
      expenses: expenses,
      now: () => T,
      hold: hold,
    );
    results = [];
    final sub = checks.results.listen(results.add);
    addTearDown(sub.cancel);
  }

  setUp(() async {
    db = KobanDatabase(NativeDatabase.memory(setup: configureConnection));
    final categories = CategoryRepository(db);
    await categories.seedIfEmpty();
    pending = PendingPaymentRepository(db, now: () => T);
    merchants = MerchantCategoryRepository(db, now: () => T);
    splits = SplitRepository(db, now: () => T);
    expenses = ExpenseRepository(
      db,
      categories: categories,
      merchants: merchants,
      splits: splits,
      now: () => DateTime.fromMillisecondsSinceEpoch(T),
    );
    useChecks(longHold);
  });
  tearDown(() async {
    // Releases a hold, so no timer fires after the database closes.
    checks.undo();
    await checks.idle;
    await db.close();
  });

  Future<String> card({
    String amount = '15.00',
    String? merchant = 'RESTORAN CONTOH',
    TransactionType type = TransactionType.withdraw,
    int? postTime,
    String? key = 'k1',
  }) async => (await pending.capture(
    parsed: parsed(amount, merchant, type: type),
    format: CaptureFormat.known,
    rawText: qrText,
    sourcePackage: maybank,
    notificationPostTime: postTime ?? P,
    notificationKey: key,
  ))!;

  Future<List<PendingPayment>> cards() => db.select(db.pendingPayments).get();
  Future<List<Expense>> payments() => db.select(db.expenses).get();
  Future<List<DroppedNotification>> drops() =>
      db.select(db.droppedNotifications).get();
  Future<List<String>> visible() async => [
    for (final p in await checks.watchVisible().first) p.id,
  ];

  /// Ends the window of the hold now, then waits until no commit runs.
  Future<void> endWindow() async {
    checks.flushHold();
    await checks.idle;
  }

  Future<void> addPayment({String amount = '15.00', int? postTime}) => db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: 'old',
          amount: d(amount),
          currency: 'MYR',
          merchant: const Value('RESTORAN CONTOH'),
          rawNotificationText: 'x',
          sourcePackage: maybank,
          notificationPostTime: postTime ?? P,
          createdAt: T,
          dedupKey: 'other',
          status: ExpenseStatus.autoSaved,
          confidence: ParseConfidence.high,
          transactionType: TransactionType.withdraw,
          privateToGroups: false,
        ),
      );

  test(
    'a held save commits after the hold and the card becomes a payment',
    () async {
      useChecks(timerHold);
      await merchants.saveMapping('RESTORAN CONTOH', 'food');
      final id = await card();
      final key = (await cards()).single.dedupKey;
      final seen = <List<String>>[];
      final sub = checks.watchVisible().listen(
        (l) => seen.add([for (final p in l) p.id]),
      );
      addTearDown(sub.cancel);
      await pumpEventQueue();

      checks.hold(id, save: true);
      final committed = checks.results.first;
      // The reads go to the database before the timer can fire, and the
      // database runs them in order, so a commit cannot come before them.
      final cardsNow = cards();
      final paymentsNow = payments();
      final visibleNow = visible();
      expect((await cardsNow).length, 1);
      expect(await paymentsNow, isEmpty);
      expect(await visibleNow, <String>[]);
      expect(results, isEmpty);

      expect(
        await committed.timeout(const Duration(seconds: 30)),
        ConfirmResult.saved,
      );
      await checks.idle;
      await pumpEventQueue();
      final e = (await payments()).single;
      expect(e.amount, d('15.00'));
      expect(e.merchant, 'RESTORAN CONTOH');
      expect(e.categoryId, 'food');
      expect(e.status, ExpenseStatus.autoSaved);
      expect(e.confidence, ParseConfidence.high);
      expect(e.dedupKey, key);
      expect(e.notificationKey, 'k1');
      expect(e.notificationPostTime, P);
      expect(e.createdAt, T);
      expect(e.notes, isNull);
      expect(e.transactionType, TransactionType.withdraw);
      expect(await cards(), isEmpty);
      expect(results, [ConfirmResult.saved]);
      // The card does not show again between the commit and the new rows.
      expect(seen.first, [id]);
      expect(seen.skip(1), isNotEmpty);
      expect(seen.skip(1), everyElement(isEmpty));
    },
  );

  test(
    'undo inside the window brings the card back and writes nothing',
    () async {
      final id = await card();
      checks.hold(id, save: true);
      expect(await visible(), <String>[]);

      expect(checks.undo(), true);
      expect(await visible(), [id]);
      expect(checks.undo(), false);

      // The released hold is not committed by a flush.
      await endWindow();
      expect(await payments(), isEmpty);
      expect((await cards()).single.id, id);
      expect(results, isEmpty);
    },
  );

  test('a swipe of another card commits the first at once', () async {
    final a = await card();
    final b = await card(
      amount: '8.50',
      merchant: 'Kedai Contoh',
      key: 'k2',
      postTime: P - 600000,
    );
    checks.hold(a, save: true);
    checks.hold(b, save: true);
    await checks.idle;

    expect([for (final e in await payments()) e.amount], [d('15.00')]);
    expect([for (final c in await cards()) c.id], [b]);
    expect(await visible(), <String>[]);
    expect(results, [ConfirmResult.saved]);

    await endWindow();
    expect((await payments()).length, 2);
    expect(await cards(), isEmpty);
  });

  test('a second swipe of the same card only changes the choice', () async {
    final id = await card();
    checks.hold(id, save: true);
    checks.hold(id, save: false);
    await checks.idle;
    expect((await cards()).length, 1);
    expect(await visible(), <String>[]);

    await endWindow();
    expect(await payments(), isEmpty);
    expect((await drops()).length, 1);
    expect(await cards(), isEmpty);
    expect(results, [ConfirmResult.dropped]);
  });

  test('flush commits the hold at once', () async {
    final id = await card();
    checks.hold(id, save: true);
    checks.flushHold();
    await checks.idle;
    expect((await payments()).length, 1);
    expect(await cards(), isEmpty);
    expect(results, [ConfirmResult.saved]);

    // A second flush writes nothing more.
    await endWindow();
    expect((await payments()).length, 1);
    expect(results, [ConfirmResult.saved]);
    expect(checks.undo(), false);
  });

  test('Not a payment writes a drop marker so the same notification does not come back', () async {
    final id = await card();
    final key = (await cards()).single.dedupKey;
    checks.hold(id, save: false);
    checks.flushHold();
    await checks.idle;

    final drop = (await drops()).single;
    expect(drop.dedupKey, key);
    expect(drop.notificationKey, 'k1@$P');
    expect(drop.droppedAt, T);
    expect(await cards(), isEmpty);
    expect(await payments(), isEmpty);
    expect(results, [ConfirmResult.dropped]);

    expect(
      await pending.capture(
        parsed: parsed('15.00', 'RESTORAN CONTOH'),
        format: CaptureFormat.known,
        rawText: qrText,
        sourcePackage: maybank,
        notificationPostTime: P,
        notificationKey: 'k1',
      ),
      isNull,
    );
    // Touch 'n Go uses one key for every payment: another payment with the key still comes.
    expect(
      await pending.capture(
        parsed: parsed('8.50', 'RESTORAN CONTOH'),
        format: CaptureFormat.known,
        rawText: qrText,
        sourcePackage: maybank,
        notificationPostTime: P + 60000,
        notificationKey: 'k1',
      ),
      isNotNull,
    );
  });

  test(
    'a card that a payment already covers is removed and reports already saved',
    () async {
      final id = await card();
      await addPayment();
      checks.hold(id, save: true);
      checks.flushHold();
      await checks.idle;

      expect([for (final e in await payments()) e.id], ['old']);
      expect(await cards(), isEmpty);
      expect(results, [ConfirmResult.alreadySaved]);
      expect(await visible(), <String>[]);
    },
  );

  test(
    'an edited card saves as EDITED and teaches the shop its category',
    () async {
      final id = await card();
      final before = (await cards()).single;
      await checks.update(
        before.copyWith(
          amount: d('15.5'),
          merchant: const Value('Kedai Contoh'),
          categoryId: const Value('food'),
        ),
      );

      final after = (await cards()).single;
      expect(after.edited, true);
      expect(
        after.dedupKey,
        DedupKeyGenerator.generate(
          packageName: maybank,
          amount: d('15.50'),
          merchant: 'Kedai Contoh',
          postTime: P,
        ),
      );
      expect(after.dedupKey, isNot(before.dedupKey));
      final rawAmount = await db
          .customSelect('SELECT amount FROM pending_payments')
          .getSingle();
      expect(rawAmount.read<String>('amount'), '15.50');

      checks.hold(id, save: true);
      checks.flushHold();
      await checks.idle;
      final e = (await payments()).single;
      expect(e.status, ExpenseStatus.edited);
      expect(e.merchant, 'Kedai Contoh');
      expect(e.categoryId, 'food');
      expect(e.amount, d('15.50'));
      final map = (await db.select(db.merchantCategoryMap).get()).single;
      expect(
        (map.merchantKey, map.displayName, map.categoryId),
        ('kedai contoh', 'Kedai Contoh', 'food'),
      );
    },
  );

  test(
    'a forced card keeps its key on edit and saves next to an equal payment',
    () async {
      expect(
        await pending.forceCapture(
          sourcePackage: maybank,
          rawText: qrText,
          notificationPostTime: P,
        ),
        true,
      );
      await addPayment();
      final forced = (await cards()).single;
      expect(forced.dedupKey, startsWith('forced:'));

      await checks.update(
        forced.copyWith(merchant: const Value('Kedai Contoh')),
      );
      final after = (await cards()).single;
      expect(after.dedupKey, forced.dedupKey);
      expect(after.edited, true);

      checks.hold(forced.id, save: true);
      checks.flushHold();
      await checks.idle;
      expect((await payments()).length, 2);
      expect(await cards(), isEmpty);
      expect(results, [ConfirmResult.saved]);
    },
  );

  test('a received card that fits a debt becomes its suggestion', () async {
    await splits.saveSplit(
      SplitDraft(
        billId: null,
        merchant: 'RESTORAN CONTOH',
        billTime: T - 86400000,
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
            lastUsedAt: T,
            archived: false,
          ),
        ],
        linkedExpenseId: null,
      ),
    );
    final id = await card(
      amount: '14.00',
      merchant: 'ALI',
      type: TransactionType.receive,
    );
    checks.hold(id, save: true);
    checks.flushHold();
    await checks.idle;

    final e = (await payments()).single;
    expect(e.transactionType, TransactionType.receive);
    final debt = (await db.select(db.splitDebts).get()).single;
    expect(debt.amount, d('14.00'));
    expect(debt.suggestedRepaymentExpenseId, e.id);
  });
}
