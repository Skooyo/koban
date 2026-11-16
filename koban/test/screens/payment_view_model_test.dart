import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/payment/payment_view_model.dart';

import '../support/harness.dart';

Future<int> countExpenses(KobanDatabase db) async =>
    (await db.customSelect('SELECT COUNT(*) AS c FROM expenses').getSingle())
        .read<int>('c');

Future<List<Expense>> allExpenses(KobanDatabase db) =>
    db.select(db.expenses).get();

final edited = DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch;

/// One saved payment of 15.00 at 11 Nov 20:15, and its id.
Future<String> addOne(AppServices s) async {
  await s.expenses.addManualExpense(
    amount: Decimal.parse('15.00'),
    merchant: 'Kedai Contoh',
    postTime: edited,
    categoryId: 'food',
    notes: 'Makan',
    type: TransactionType.withdraw,
  );
  return (await allExpenses(s.db)).single.id;
}

void typeAmount(PaymentViewModel vm, String text) => vm.setAmount(text);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('a new payment starts empty as a spend at now', () async {
    final s = await testServices();
    final vm = PaymentViewModel(s);
    addTearDown(vm.dispose);
    expect(
      vm.form,
      PaymentForm(
        amountText: '',
        type: TransactionType.withdraw,
        categoryId: null,
        postTime: DateTime(2026, 11, 13, 12).millisecondsSinceEpoch,
        merchant: '',
        notes: '',
      ),
    );
    expect(vm.isEditing, false);
    expect(vm.loadedCategoryId, null);
    expect(vm.hasChanges, false);
    vm.setAmount('5');
    expect(vm.hasChanges, true);
    vm.setAmount('');
    expect(vm.hasChanges, false);
  });

  test(
    'save of a new spend adds one manual payment and says Payment saved',
    () async {
      final s = await testServices();
      final vm = PaymentViewModel(s);
      addTearDown(vm.dispose);
      typeAmount(vm, '12.5');
      vm.setMerchant('Kedai Contoh');
      vm.setCategory('food');
      final r = await vm.save();
      expect((r as PaymentClosed).message, 'Payment saved');
      final e = (await allExpenses(s.db)).single;
      expect(e.amount, Decimal.parse('12.50'));
      expect(e.merchant, 'Kedai Contoh');
      expect(e.categoryId, 'food');
      expect(e.sourcePackage, 'manual');
      expect(e.transactionType, TransactionType.withdraw);
      expect(e.notes, null);
      expect(
        e.notificationPostTime,
        DateTime(2026, 11, 13, 12).millisecondsSinceEpoch,
      );
    },
  );

  test('save of a new receive says Payment saved', () async {
    final s = await testServices();
    final vm = PaymentViewModel(s);
    addTearDown(vm.dispose);
    vm.setType(TransactionType.receive);
    typeAmount(vm, '30');
    final r = await vm.save();
    expect((r as PaymentClosed).message, 'Payment saved');
    expect(
      (await allExpenses(s.db)).single.transactionType,
      TransactionType.receive,
    );
  });

  test('save of an edit says nothing and keeps the id', () async {
    final s = await testServices();
    final id = await addOne(s);
    final vm = PaymentViewModel(s, expenseId: id);
    addTearDown(vm.dispose);
    await vm.ready;
    expect(vm.isEditing, true);
    expect(vm.loadedCategoryId, 'food');
    expect(
      vm.form,
      PaymentForm(
        amountText: '15.00',
        type: TransactionType.withdraw,
        categoryId: 'food',
        postTime: edited,
        merchant: 'Kedai Contoh',
        notes: 'Makan',
      ),
    );
    expect(vm.hasChanges, false);
    typeAmount(vm, '16.5');
    final r = await vm.save();
    expect((r as PaymentClosed).message, null);
    final e = (await allExpenses(s.db)).single;
    expect(e.id, id);
    expect(e.amount, Decimal.parse('16.50'));
  });

  // Review Focus 4
  test('a second save during the first adds one payment', () async {
    final s = await testServices();
    final vm = PaymentViewModel(s);
    addTearDown(vm.dispose);
    typeAmount(vm, '9');
    final r = await Future.wait([vm.save(), vm.save()]);
    expect(r.whereType<PaymentClosed>().length, 1);
    expect(r.where((x) => x == null).length, 1);
    expect(await countExpenses(s.db), 1);
  });

  test('delete marks the payment dismissed and says Payment deleted', () async {
    final s = await testServices();
    final id = await addOne(s);
    final vm = PaymentViewModel(s, expenseId: id);
    addTearDown(vm.dispose);
    await vm.ready;
    final r = await Future.wait([vm.delete(), vm.delete()]);
    expect(
      r.whereType<PaymentClosed>().single.message,
      'Payment deleted: Kedai Contoh, RM 15.00',
    );
    expect(r.where((x) => x == null).length, 1);
    expect((await allExpenses(s.db)).single.status, ExpenseStatus.dismissed);
  });

  test('an edit of a missing payment closes at once', () async {
    final s = await testServices();
    final vm = PaymentViewModel(s, expenseId: 'missing');
    addTearDown(vm.dispose);
    await vm.ready;
    expect((vm.closeNow as PaymentClosed).message, null);
    expect(vm.form, null);
  });

  test('save with no amount does nothing', () async {
    final s = await testServices();
    final vm = PaymentViewModel(s);
    addTearDown(vm.dispose);
    typeAmount(vm, '0');
    expect(await vm.save(), null);
    expect(vm.saving, false);
    expect(await countExpenses(s.db), 0);
  });
}
