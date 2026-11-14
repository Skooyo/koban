import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/expense_repository.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/payment/payment_view_model.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

/// A page with one button. The button opens the payment sheet and keeps what it gives back.
class Opener extends StatefulWidget {
  const Opener({super.key, this.expenseId});

  final String? expenseId;

  @override
  State<Opener> createState() => OpenerState();
}

class OpenerState extends State<Opener> {
  bool closed = false;
  PaymentResult? result;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final id = widget.expenseId;
          final r = id == null
              ? await openPaymentNew(context)
              : await openPaymentEdit(context, id);
          setState(() {
            closed = true;
            result = r;
          });
        },
        child: const Text('Open sheet'),
      ),
    ),
  );
}

Future<OpenerState> openSheet(
  WidgetTester tester,
  AppServices s, {
  String? expenseId,
  double textScale = 1,
}) async {
  await pumpKoban(
    tester,
    s,
    home: Opener(expenseId: expenseId),
    textScale: textScale,
  );
  // The tree goes first, so the category stream ends before the database closes.
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  await tester.tap(find.text('Open sheet'));
  await tester.pumpAndSettle();
  return tester.state<OpenerState>(find.byType(Opener, skipOffstage: false));
}

Future<int> countExpenses(KobanDatabase db) async =>
    (await db.customSelect('SELECT COUNT(*) AS c FROM expenses').getSingle())
        .read<int>('c');

Future<String> addOne(AppServices s) async {
  await s.expenses.addManualExpense(
    amount: Decimal.parse('15.00'),
    merchant: 'Kedai Contoh',
    postTime: DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch,
    categoryId: 'food',
    notes: null,
    type: TransactionType.withdraw,
  );
  return (await s.db.select(s.db.expenses).get()).single.id;
}

Future<void> tapKeys(WidgetTester tester, String keys) async {
  for (final k in keys.split('')) {
    await tester.tap(find.text(k));
    await tester.pump();
  }
}

bool saveOn(WidgetTester tester, String label) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed !=
    null;

void main() {
  testWidgets('a new payment opens with the number pad and Save payment off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester, await testServices());
    expect(find.text('Tap a number to change it'), findsOneWidget);
    expect(find.text('RM 0'), findsOneWidget);
    expect(find.text('Save payment'), findsOneWidget);
    expect(saveOn(tester, 'Save payment'), false);
    for (final k in '1234567890'.split('')) {
      expect(find.text(k), findsOneWidget);
    }
    expect(find.bySemanticsLabel('Decimal point'), findsOneWidget);
    expect(find.bySemanticsLabel('Delete digit'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount empty'), findsOneWidget);
    await tapKeys(tester, '12.5');
    expect(find.text('RM 12.5'), findsOneWidget);
    expect(find.bySemanticsLabel('Amount RM 12.5'), findsOneWidget);
    expect(saveOn(tester, 'Save payment'), true);
    handle.dispose();
  });

  testWidgets('saving closes the sheet with Expense added', (tester) async {
    final s = await testServices();
    final opener = await openSheet(tester, s);
    await tapKeys(tester, '8');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    expect((opener.result as PaymentClosed).message, 'Expense added');
    expect(await countExpenses(s.db), 1);
  });

  testWidgets(
    'an edit shows Payment, the direction and date line and Save changes',
    (tester) async {
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Spent · Wed, 11 Nov, 20:15'), findsOneWidget);
      expect(find.text('Save changes'), findsOneWidget);
      expect(find.text('RM 15.00'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Kedai Contoh'), findsOneWidget);
      expect(find.byTooltip('Delete payment'), findsOneWidget);
      expect(find.text('7'), findsNothing);
      await tester.tap(find.text('RM 15.00'));
      await tester.pumpAndSettle();
      expect(find.text('7'), findsOneWidget);
    },
  );

  testWidgets('delete asks first and then closes with Payment deleted', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addOne(s);
    final opener = await openSheet(tester, s, expenseId: id);
    await tester.tap(find.byTooltip('Delete payment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsOneWidget);
    expect(
      find.text('It will no longer count in your totals.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsNothing);
    expect(opener.closed, false);
    await tester.tap(find.byTooltip('Delete payment'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    expect((opener.result as PaymentClosed).message, 'Payment deleted');
    expect(
      (await s.db.select(s.db.expenses).get()).single.status,
      ExpenseStatus.dismissed,
    );
  });

  // Review Focus 4
  testWidgets('Back with typed data asks before it discards', (tester) async {
    final s = await testServices();
    final opener = await openSheet(tester, s);
    await tapKeys(tester, '5');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(opener.closed, false);
    expect(find.text('RM 5'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    expect(opener.result, null);
    expect(await countExpenses(s.db), 0);
  });

  testWidgets('X with typed data asks too, and with no change closes at once', (
    tester,
  ) async {
    final s = await testServices();
    var opener = await openSheet(tester, s);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(opener.closed, true);
    expect(opener.result, null);

    await tester.tap(find.text('Open sheet'));
    await tester.pumpAndSettle();
    await tapKeys(tester, '5');
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    opener = tester.state<OpenerState>(
      find.byType(Opener, skipOffstage: false),
    );
    expect(opener.result, null);
    expect(await countExpenses(s.db), 0);
  });

  testWidgets('Back with no change closes at once', (tester) async {
    final opener = await openSheet(tester, await testServices());
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsNothing);
    expect(opener.closed, true);
  });

  testWidgets('a new category with a shop shows the past payments hint', (
    tester,
  ) async {
    await openSheet(tester, await testServices());
    const hint = 'A new category also applies to past payments from this shop';
    await tester.ensureVisible(find.text('Shop'));
    await tester.tap(find.text('Shop'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Kedai Contoh');
    await tester.pump();
    expect(find.text(hint), findsNothing);
    await tester.tap(find.text('Uncategorized'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets(
    'the category sheet lists categories by name and marks the chosen one',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id);
      await tester.tap(find.text('Food & Dining'));
      await tester.pumpAndSettle();
      expect(find.text('Category'), findsWidgets);
      for (final n in [
        'Uncategorized',
        'Bills & Utilities',
        'Entertainment',
        'Health',
        'Other',
        'Shopping',
        'Transport',
      ]) {
        expect(find.text(n), findsOneWidget);
      }
      expect(find.bySemanticsLabel(RegExp('Selected')), findsOneWidget);
      await tester.tap(find.text('Transport'));
      await tester.pumpAndSettle();
      expect(find.text('Transport'), findsOneWidget);
      expect(find.text('Food & Dining'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets('the date picker offers no day after today', (tester) async {
    await openSheet(tester, await testServices());
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    final picker = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(picker.lastDate, DateTime(2026, 11, 13));
    await tester.tap(find.text('12'));
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Yesterday'), findsOneWidget);
  });

  testWidgets('Count in group totals does not show without groups', (
    tester,
  ) async {
    await openSheet(tester, await testServices());
    expect(find.text('Count in group totals'), findsNothing);
  });

  testWidgets(
    'the payment sheet meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id, textScale: 1.3);
      await tester.tap(find.text('RM 15.00'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets(
    'a new payment meets the guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openSheet(tester, await testServices(), textScale: 1.3);
      expect(tester.takeException(), null);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('two fast taps on Save add one payment', (tester) async {
    final s = await testServices();
    await openSheet(tester, s);
    await tapKeys(tester, '7');
    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save payment'),
    );
    save.onPressed!();
    save.onPressed!();
    await tester.pumpAndSettle();
    expect(await countExpenses(s.db), 1);
  });

  testWidgets('Back during a save closes only the sheet, and the save lands', (
    tester,
  ) async {
    final base = await testServices();
    final gate = Completer<void>();
    final s = _GatedServices(base, gate);
    await openSheet(tester, s);
    await tapKeys(tester, '7');
    await tester.tap(find.text('Save payment'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 100));
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(Opener), findsOneWidget);
    expect(find.text('Open sheet'), findsOneWidget);
    expect(await countExpenses(s.db), 1);
  });

  testWidgets(
    'Back during a delete closes only the sheet, and the delete lands',
    (tester) async {
      final base = await testServices();
      final id = await addOne(base);
      final gate = Completer<void>();
      final s = _GatedServices(base, gate);
      await openSheet(tester, s, expenseId: id);
      await tester.tap(find.byTooltip('Delete payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.binding.handlePopRoute();
      await tester.pump(const Duration(milliseconds: 100));
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('Open sheet'), findsOneWidget);
      expect(
        (await s.db.select(s.db.expenses).get()).single.status,
        ExpenseStatus.dismissed,
      );
    },
  );
}

/// Services whose repository holds each save and delete until [gate] completes.
class _GatedServices extends AppServices {
  _GatedServices(AppServices base, Completer<void> gate)
    : _gated = _GatedExpenses(base, gate),
      super(
        db: base.db,
        settings: base.settings,
        importResult: base.importResult,
        listener: base.listener,
        now: base.now,
      );

  final ExpenseRepository _gated;

  @override
  ExpenseRepository get expenses => _gated;
}

class _GatedExpenses extends ExpenseRepository {
  _GatedExpenses(AppServices base, this.gate)
    : super(
        base.db,
        categories: base.categories,
        merchants: base.merchants,
        splits: base.splits,
        now: base.now,
      );

  final Completer<void> gate;

  @override
  Future<void> addManualExpense({
    required Decimal amount,
    String? merchant,
    required int postTime,
    String? categoryId,
    String? notes,
    required TransactionType type,
    bool privateToGroups = false,
  }) async {
    await gate.future;
    return super.addManualExpense(
      amount: amount,
      merchant: merchant,
      postTime: postTime,
      categoryId: categoryId,
      notes: notes,
      type: type,
      privateToGroups: privateToGroups,
    );
  }

  @override
  Future<void> dismissExpense(String id) async {
    await gate.future;
    return super.dismissExpense(id);
  }
}
