import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/activity/activity_view_model.dart';

import '../support/harness.dart';

Future<void> pay(
  AppServices s,
  String amount,
  DateTime at, {
  String category = 'food',
}) => s.expenses.addManualExpense(
  amount: Decimal.parse(amount),
  // One shop for each category: a new category moves the other payments of a shop.
  merchant: 'Kedai $category',
  postTime: at.millisecondsSinceEpoch,
  categoryId: category,
  notes: null,
  type: TransactionType.withdraw,
);

/// Lets the streams answer.
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 80));

Future<ActivityViewModel> open(AppServices s) async {
  final vm = ActivityViewModel(s);
  addTearDown(vm.dispose);
  await settle();
  return vm;
}

List<String> amounts(ActivityViewModel vm) => [
  for (final e in vm.state.expenses) e.amount.toString(),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the month view lists the month payments, newest first', () async {
    final s = await testServices();
    await pay(s, '3.00', DateTime(2026, 11, 2, 9));
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '7.00', DateTime(2026, 11, 10, 9));
    // 30 Oct is in the first week of November, but not in the month.
    await pay(s, '9.00', DateTime(2026, 10, 30, 9));
    final vm = await open(s);
    expect(vm.state.month, const YearMonth(2026, 11));
    expect(amounts(vm), ['5', '7', '3']);
    expect(vm.state.monthTotal, Decimal.parse('15'));
    expect(vm.state.weeks.length, 6);
    // The week of 26 Oct holds the payment of 30 Oct.
    expect(vm.state.weeks.first.total, Decimal.parse('9'));
    expect(vm.state.categoryNames['food'], 'Food & Dining');
    expect(vm.allMonths, isNull);
  });

  test('a week toggle filters the list and the header total, and a second tap clears it', () async {
    final s = await testServices();
    await pay(s, '3.00', DateTime(2026, 11, 2, 9));
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '7.00', DateTime(2026, 11, 10, 9));
    final vm = await open(s);
    final week = DateTime(2026, 11, 9).millisecondsSinceEpoch;
    vm.toggleWeek(week);
    await settle();
    expect(vm.state.selectedWeek, week);
    expect(amounts(vm), ['5', '7']);
    expect(vm.state.monthTotal, Decimal.parse('12'));
    vm.toggleWeek(week);
    await settle();
    expect(vm.state.selectedWeek, isNull);
    expect(amounts(vm), ['5', '7', '3']);
    expect(vm.state.monthTotal, Decimal.parse('15'));
  });

  test('stepping months keeps the category filter', () async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '4.00', DateTime(2026, 10, 13, 9));
    await pay(s, '6.00', DateTime(2026, 10, 14, 9), category: 'transport');
    final vm = await open(s);
    vm.setCategoryFilter('food');
    vm.previousMonth();
    await settle();
    expect(vm.state.month, const YearMonth(2026, 10));
    expect(vm.state.categoryFilter, 'food');
    expect(amounts(vm), ['4']);
    // The ring and the total still cover the whole month.
    expect(vm.state.monthTotal, Decimal.parse('10'));
  });

  test('next month stops at the current month', () async {
    final s = await testServices();
    final vm = await open(s);
    expect(vm.state.canGoNext, false);
    vm.nextMonth();
    await settle();
    expect(vm.state.month, const YearMonth(2026, 11));
    vm.previousMonth();
    await settle();
    expect(vm.state.month, const YearMonth(2026, 10));
    expect(vm.state.canGoNext, true);
    vm.nextMonth();
    await settle();
    expect(vm.state.month, const YearMonth(2026, 11));
    expect(vm.state.canGoNext, false);
  });

  test(
    'the All view groups every payment by month with the month totals',
    () async {
      final s = await testServices();
      await pay(s, '5.00', DateTime(2026, 11, 13, 9));
      await pay(s, '7.00', DateTime(2026, 11, 10, 9));
      await pay(s, '4.00', DateTime(2026, 10, 13, 9));
      await pay(s, '6.00', DateTime(2026, 10, 14, 9), category: 'transport');
      final vm = await open(s);
      vm.setShowAll(true);
      await settle();
      final groups = vm.allMonths!;
      expect(
        [for (final g in groups) g.month],
        [const YearMonth(2026, 11), const YearMonth(2026, 10)],
      );
      expect(
        [for (final g in groups) g.total],
        [Decimal.parse('12'), Decimal.parse('10')],
      );
      expect(
        [for (final e in groups[0].expenses) e.amount.toString()],
        ['5', '7'],
      );
      vm.setCategoryFilter('transport');
      await settle();
      expect(vm.allMonths!.length, 1);
      expect(vm.allMonths!.single.month, const YearMonth(2026, 10));
      // The month total ignores the filter, as in the Month view.
      expect(vm.allMonths!.single.total, Decimal.parse('10'));
      vm.setShowAll(false);
      await settle();
      expect(vm.allMonths, isNull);
    },
  );

  test('the filter sheet uses all-time totals in the All view', () async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '4.00', DateTime(2026, 10, 13, 9));
    await pay(s, '6.00', DateTime(2026, 9, 14, 9), category: 'transport');
    final vm = await open(s);
    expect(vm.filterTotals.total, Decimal.parse('5'));
    expect(vm.filterTotals.breakdown.map((b) => b.categoryId), ['food']);
    vm.setShowAll(true);
    await settle();
    expect(vm.filterTotals.total, Decimal.parse('15'));
    final byId = {
      for (final b in vm.filterTotals.breakdown) b.categoryId: b.total,
    };
    expect(byId, {'food': Decimal.parse('9'), 'transport': Decimal.parse('6')});
  });

  test(
    'the month sheet adds the current month when it has no payment',
    () async {
      final s = await testServices();
      await pay(s, '4.00', DateTime(2026, 10, 13, 9));
      final vm = await open(s);
      expect(
        [for (final m in vm.sheetMonths) m.label],
        ['November 2026', 'October 2026'],
      );
      expect(vm.sheetMonths.first.total, Decimal.zero);
      await pay(s, '5.00', DateTime(2026, 11, 13, 9));
      await settle();
      expect(
        [for (final m in vm.sheetMonths) m.label],
        ['November 2026', 'October 2026'],
      );
      expect(vm.sheetMonths.first.total, Decimal.parse('5'));
    },
  );

  test(
    'a week that crosses the month edge counts its days in both months',
    () async {
      final s = await testServices();
      await pay(s, '9.00', DateTime(2026, 10, 30, 9));
      await pay(s, '2.00', DateTime(2026, 11, 1, 9));
      await pay(s, '3.00', DateTime(2026, 11, 2, 9));
      final vm = await open(s);
      final week = DateTime(2026, 10, 26).millisecondsSinceEpoch;
      expect(vm.state.weeks.first.label, 'Mon 26 Oct – Sun 1 Nov');
      vm.toggleWeek(week);
      await settle();
      expect(vm.state.selectedWeek, week);
      expect(vm.state.month, const YearMonth(2026, 11));
      expect(amounts(vm), ['2', '9']);
      expect(vm.state.monthTotal, Decimal.parse('11'));
    },
  );
}
