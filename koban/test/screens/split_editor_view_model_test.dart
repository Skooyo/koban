import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/split/split_editor_view_model.dart';

import '../support/harness.dart';

Decimal d(String v) => Decimal.parse(v);

final billDay = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;
final paidAt = DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch;

const ali = SplitPeopleData(
  id: 'ali',
  name: 'Ali',
  lastUsedAt: 0,
  archived: false,
);

/// The draft of the brief: Nasi lemak 20.00 for Me and Ali, Teh ais 4.00 for Ali.
SplitEditorState draft({Decimal? printedTotal, String rounding = ''}) =>
    SplitEditorState(
      billTime: billDay,
      merchant: 'Kedai Contoh',
      printedTotal: printedTotal,
      rounding: rounding,
      items: const [
        ItemRow(
          key: 0,
          name: 'Nasi lemak',
          price: '20.00',
          sharedBy: {meId, 'ali'},
        ),
        ItemRow(key: 1, name: 'Teh ais', price: '4.00', sharedBy: {'ali'}),
      ],
      people: const [ali],
    );

/// One spend of [amount] at 11 Nov 20:15, and its id.
Future<String> addPayment(AppServices s, {String amount = '24.00'}) async {
  await s.expenses.addManualExpense(
    amount: d(amount),
    merchant: 'Kedai Contoh',
    postTime: paidAt,
    type: TransactionType.withdraw,
  );
  return (await s.db.select(s.db.expenses).get()).last.id;
}

/// Saves the draft of the brief with the repository, and gives the bill id.
Future<String> saveDraft(AppServices s, {String? linkedExpenseId}) =>
    s.splits.saveSplit(
      SplitDraft(
        billId: null,
        merchant: 'Kedai Contoh',
        billTime: billDay,
        currency: 'MYR',
        printedTotal: null,
        items: [
          DraftItem(
            name: 'Nasi lemak',
            quantity: 1,
            price: d('20.00'),
            sharedBy: {meId, 'ali'},
          ),
          DraftItem(
            name: 'Teh ais',
            quantity: 1,
            price: d('4.00'),
            sharedBy: {'ali'},
          ),
        ],
        charges: SplitCharges(),
        people: const [ali],
        linkedExpenseId: linkedExpenseId,
      ),
    );

Future<SplitEditorViewModel> open(
  AppServices s, {
  String? billId,
  String? expenseId,
}) async {
  final vm = SplitEditorViewModel(s, billId: billId, expenseId: expenseId);
  addTearDown(vm.dispose);
  await vm.ready;
  return vm;
}

/// Types the draft of the brief into [vm] and moves to the summary.
void typeDraft(SplitEditorViewModel vm) {
  vm.typeItemsInstead();
  vm.setMerchant('Kedai Contoh');
  final first = vm.state.items.single.key;
  vm.updateItem(first, (r) => r.copyWith(name: 'Nasi lemak', price: '20.00'));
  vm.addItem();
  final second = vm.state.items.last.key;
  vm.updateItem(second, (r) => r.copyWith(name: 'Teh ais', price: '4.00'));
  vm.next();
  vm.addPerson('Ali');
  vm.next();
  final aliId = vm.state.people.single.id;
  vm.toggleShare(first, meId);
  vm.toggleShare(first, aliId);
  vm.toggleShare(second, aliId);
  vm.next();
  vm.next();
}

Future<List<(String, Decimal, DebtStatus)>> debts(AppServices s) async {
  final names = {
    for (final p in await s.db.select(s.db.splitPeople).get()) p.id: p.name,
  };
  return [
    for (final x in await s.db.select(s.db.splitDebts).get())
      (names[x.personId]!, x.amount, x.status),
  ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a row with no name, a bad quantity or a price of 0 makes the items invalid', () {
    final good = draft();
    expect(SplitEditorViewModel.parseItems(good)!.map((i) => i.price), [
      d('20.00'),
      d('4.00'),
    ]);
    ItemRow first(SplitEditorState s) => s.items.first;
    SplitEditorState withFirst(ItemRow r) =>
        good.copyWith(items: [r, good.items.last]);
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(name: '  ')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(quantity: '0')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(quantity: 'two')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(price: '0')),
      ),
      null,
    );
  });

  test('the difference is the printed total minus the computed total, null when equal', () {
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('24.50'))),
      d('0.50'),
    );
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('23.00'))),
      d('-1.00'),
    );
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('24.00'))),
      null,
    );
    expect(SplitEditorViewModel.difference(draft()), null);
  });

  test('add rounding difference moves the whole gap into rounding', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    await s.db.customStatement(
      "UPDATE split_bills SET printedTotal = '24.50' WHERE id = ?",
      [billId],
    );
    final vm = await open(s, billId: billId);
    vm.editItems();
    vm.addRoundingDifference();
    expect(vm.state.rounding, '0.50');
    expect(SplitEditorViewModel.difference(vm.state), null);
    expect(SplitEditorViewModel.totalOf(vm.state), d('24.50'));
  });

  test('the summary lines list the others first and Me last', () {
    expect(SplitEditorViewModel.summaryLines(draft()), [
      ('Ali', d('14.00')),
      ('Me', d('10.00')),
    ]);
    final unassigned = draft().copyWith(
      items: [
        draft().items.first,
        draft().items.last.copyWith(sharedBy: {}),
      ],
    );
    expect(SplitEditorViewModel.summaryLines(unassigned), null);
  });

  test('the share text has the place, the date, each share and the total', () {
    expect(
      SplitEditorViewModel.shareText(draft()),
      'Kedai Contoh, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00',
    );
    expect(
      SplitEditorViewModel.shareText(draft().copyWith(merchant: ' ')),
      'Bill, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00',
    );
  });

  test(
    'a person named Me or a name already in the list is not added',
    () async {
      final vm = await open(await testServices());
      vm.addPerson('Ali');
      vm.addPerson('me');
      vm.addPerson(' ali ');
      vm.addPerson('   ');
      vm.addPerson('Mei');
      expect(vm.state.people.map((p) => p.name), ['Ali', 'Mei']);
    },
  );

  test('removing a person also removes them from every item', () async {
    final vm = await open(await testServices());
    typeDraft(vm);
    final person = vm.state.people.single;
    vm.togglePerson(person);
    expect(vm.state.people, isEmpty);
    expect(vm.state.items.map((i) => i.sharedBy), [
      {meId},
      <String>{},
    ]);
  });

  test(
    'a split from a payment links it and takes its time as the bill time',
    () async {
      final s = await testServices();
      final id = await addPayment(s);
      final vm = await open(s, expenseId: id);
      expect(vm.state.loading, false);
      expect(vm.state.step, SplitStep.photo);
      expect(vm.state.selectedExpenseId, id);
      expect(vm.state.billTime, paidAt);
      expect(vm.state.billId, null);
    },
  );

  test(
    'a saved split that fails to load ends the spinner with the error text',
    () async {
      final s = await testServices();
      final id = await saveDraft(s);
      await s.db.customStatement('DROP TABLE split_item_shares');

      final vm = await open(s, billId: id);

      expect(vm.state.loading, false);
      expect(vm.state.error, 'Something went wrong. Try again.');
    },
  );

  test(
    'a payment that already has a split opens that split on the summary',
    () async {
      final s = await testServices();
      final id = await addPayment(s);
      final billId = await saveDraft(s, linkedExpenseId: id);
      final vm = await open(s, expenseId: id);
      expect(vm.state.billId, billId);
      expect(vm.state.step, SplitStep.summary);
      expect(vm.state.locked, false);
      expect(vm.state.merchant, 'Kedai Contoh');
      expect(vm.state.items.map((i) => (i.name, i.quantity, i.price)), [
        ('Nasi lemak', '1', '20.00'),
        ('Teh ais', '1', '4.00'),
      ]);
      expect(vm.state.selectedExpenseId, id);
      expect(SplitEditorViewModel.summaryLines(vm.state), [
        ('Ali', d('14.00')),
        ('Me', d('10.00')),
      ]);
    },
  );

  test(
    'back on a saved bill in edit mode asks first, and on a viewed bill leaves',
    () async {
      final s = await testServices();
      final billId = await saveDraft(s);
      final vm = await open(s, billId: billId);
      expect(vm.back(), false);
      vm.editItems();
      expect(vm.state.step, SplitStep.items);
      expect(vm.back(), true);
      expect(vm.state.confirmDiscard, true);
      expect(vm.state.step, SplitStep.items);
      vm.keepEditing();
      expect(vm.state.confirmDiscard, false);
      vm.discardEdits();
      expect(vm.state.confirmDiscard, false);

      final fresh = await open(s);
      fresh.typeItemsInstead();
      expect(fresh.back(), true);
      expect(fresh.state.step, SplitStep.photo);
      expect(fresh.state.confirmDiscard, false);
      expect(fresh.back(), false);
    },
  );

  test('done on a viewed bill saves nothing', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final before = await s.db.select(s.db.splitDebts).get();
    final vm = await open(s, billId: billId);
    await vm.done();
    expect(vm.state.finished, true);
    final after = await s.db.select(s.db.splitDebts).get();
    expect(after.map((x) => x.id), before.map((x) => x.id));
  });

  test('done saves the split and finishes', () async {
    final s = await testServices();
    final vm = await open(s);
    typeDraft(vm);
    expect(vm.state.step, SplitStep.summary);
    await vm.done();
    expect(vm.state.finished, true);
    expect(vm.state.error, null);
    expect(await debts(s), [('Ali', d('14.00'), DebtStatus.open)]);
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect(bill.merchant, 'Kedai Contoh');
    expect(bill.billTime, billDay);
  });

  test('a locked bill only saves its payment link', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final debt = (await s.db.select(s.db.splitDebts).get()).single;
    await s.splits.markPaid(debt.id, null);
    final id = await addPayment(s, amount: '24.00');
    final vm = await open(s, billId: billId);
    expect(vm.state.locked, true);
    await vm.done();
    expect(vm.state.finished, false);
    vm.changePayment();
    expect(vm.state.step, SplitStep.link);
    vm.selectExpense(id);
    await vm.saveLockedPayment();
    expect(vm.state.step, SplitStep.summary);
    expect(vm.state.error, null);
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect(bill.linkedExpenseId, id);
    expect(await debts(s), [('Ali', d('14.00'), DebtStatus.paid)]);
    final payment = await s.expenses.getById(id);
    expect(payment!.countedAmount, d('10.00'));
  });
}
