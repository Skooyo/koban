import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/expense_repository.dart';
import 'package:koban/data/undoable.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/payment/payment_view_model.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';

import '../online/group_repository_test.dart' show jsonReply;
import '../online/group_session_test.dart' show storedSession, tokenReply;
import '../support/fake_backend.dart';
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

/// The amount field is the first text field on the page.
Finder get amountField => find.byType(TextField).first;

String amountText(WidgetTester tester) =>
    tester.widget<TextField>(amountField).controller!.text;

Future<void> typeAmount(WidgetTester tester, String text) async {
  await tester.enterText(amountField, text);
  await tester.pump();
}

bool saveOn(WidgetTester tester, String label) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed !=
    null;

void main() {
  testWidgets('a new payment opens with the keyboard and Save payment off', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await openSheet(tester, await testServices());
    expect(find.text('Type the amount.'), findsOneWidget);
    expect(find.text('RM '), findsOneWidget);
    expect(find.text('Save payment'), findsOneWidget);
    expect(saveOn(tester, 'Save payment'), false);
    final field = tester.widget<TextField>(amountField);
    expect(field.focusNode!.hasFocus, true);
    expect(
      field.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    expect(find.text('7'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Amount')), findsOneWidget);
    await typeAmount(tester, '12.5');
    expect(find.text('Type the amount.'), findsNothing);
    expect(amountText(tester), '12.5');
    expect(saveOn(tester, 'Save payment'), true);
    handle.dispose();
  });

  testWidgets('typing 12.5 then Save stores 12.50', (tester) async {
    final s = await testServices();
    await openSheet(tester, s);
    await typeAmount(tester, '12.5');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(
      (await s.db.select(s.db.expenses).get()).single.amount,
      Decimal.parse('12.50'),
    );
  });

  testWidgets('letters, a second dot and a third decimal are rejected', (
    tester,
  ) async {
    await openSheet(tester, await testServices());
    await typeAmount(tester, '12.5');
    await typeAmount(tester, '12.5x');
    expect(amountText(tester), '12.5');
    await typeAmount(tester, '12.5.');
    expect(amountText(tester), '12.5');
    await typeAmount(tester, '12.55');
    expect(amountText(tester), '12.55');
    await typeAmount(tester, '12.555');
    expect(amountText(tester), '12.55');
    await typeAmount(tester, '1234567890');
    expect(amountText(tester), '12.55');
    await typeAmount(tester, '.5');
    expect(amountText(tester), '0.5');
  });

  testWidgets('saving closes the sheet with Payment saved', (tester) async {
    final s = await testServices();
    final opener = await openSheet(tester, s);
    await typeAmount(tester, '8');
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    expect((opener.result as PaymentClosed).message, 'Payment saved');
    expect(await countExpenses(s.db), 1);
  });

  testWidgets(
    'an edit shows Payment, the direction and date line and Save payment',
    (tester) async {
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id);
      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('Spent · Wed, 11 Nov, 20:15'), findsOneWidget);
      expect(find.text('Save payment'), findsOneWidget);
      expect(find.text('Food & Dining'), findsOneWidget);
      expect(find.text('Kedai Contoh'), findsOneWidget);
      expect(find.byTooltip('Delete payment'), findsOneWidget);
      expect(amountText(tester), '15.00');
      expect(tester.widget<TextField>(amountField).focusNode!.hasFocus, false);
      await tester.tap(amountField);
      await tester.pumpAndSettle();
      expect(tester.widget<TextField>(amountField).focusNode!.hasFocus, true);
    },
  );

  testWidgets('delete closes the page at once with no dialog', (tester) async {
    final s = await testServices();
    final id = await addOne(s);
    final opener = await openSheet(tester, s, expenseId: id);
    await tester.tap(find.byTooltip('Delete payment'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this payment?'), findsNothing);
    expect(opener.closed, true);
    final closed = opener.result as PaymentClosed;
    expect(closed.message, 'Payment deleted: Kedai Contoh, RM 15.00');
    expect(closed.undo, isNotNull);
    expect(
      (await s.db.select(s.db.expenses).get()).single.status,
      ExpenseStatus.dismissed,
    );
  });

  // Review Focus 4
  testWidgets('Back with typed data asks before it discards', (tester) async {
    final s = await testServices();
    final opener = await openSheet(tester, s);
    await typeAmount(tester, '5');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(opener.closed, false);
    expect(amountText(tester), '5');
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
    await typeAmount(tester, '5');
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
    await tester.enterText(find.byType(TextField).at(1), 'Kedai Contoh');
    await tester.pump();
    expect(find.text(hint), findsNothing);
    await tester.tap(find.text('Health'));
    await tester.pumpAndSettle();
    expect(find.text(hint), findsOneWidget);
  });

  testWidgets(
    'the category chips show four, More opens the full sheet, a pick moves the chip',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id);
      ChoiceChip chip(String n) =>
          tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, n));
      expect(find.text('Category'), findsOneWidget);
      for (final n in [
        'Bills & Utilities',
        'Entertainment',
        'Food & Dining',
        'Health',
      ]) {
        expect(find.widgetWithText(ChoiceChip, n), findsOneWidget);
      }
      expect(find.widgetWithText(ChoiceChip, 'Transport'), findsNothing);
      expect(chip('Food & Dining').selected, true);
      expect(chip('Health').selected, false);
      await tester.ensureVisible(find.text('More…'));
      await tester.tap(find.text('More…'));
      await tester.pumpAndSettle();
      Finder inSheet(String n) => find.widgetWithText(KobanRow, n);
      for (final n in [
        'Uncategorized',
        'Bills & Utilities',
        'Entertainment',
        'Health',
        'Other',
        'Shopping',
        'Transport',
      ]) {
        expect(inSheet(n), findsOneWidget);
      }
      expect(find.bySemanticsLabel(RegExp('Selected')), findsOneWidget);
      await tester.tap(inSheet('Transport'));
      await tester.pumpAndSettle();
      // The chosen category takes the last chip.
      expect(chip('Transport').selected, true);
      expect(find.widgetWithText(ChoiceChip, 'Health'), findsNothing);
      handle.dispose();
    },
  );

  testWidgets(
    'a new payment hints how to type the amount, then the date line',
    (tester) async {
      await openSheet(tester, await testServices());
      expect(find.text('Type the amount.'), findsOneWidget);
      await typeAmount(tester, '5');
      expect(find.text('Type the amount.'), findsNothing);
      expect(find.textContaining('Spent · '), findsOneWidget);
    },
  );

  testWidgets(
    'with the keyboard up, Save payment, the amount and the chips stay usable',
    (tester) async {
      tester.view.physicalSize = const Size(1280, 2772);
      tester.view.devicePixelRatio = 1280 / 390;
      tester.view.viewInsets = const FakeViewPadding(bottom: 1000);
      addTearDown(tester.view.reset);
      final s = await testServices();
      await s.expenses.addManualExpense(
        amount: Decimal.parse('5.00'),
        merchant: 'Grab',
        postTime: DateTime(2026, 11, 5, 12).millisecondsSinceEpoch,
        categoryId: 'transport',
        notes: null,
        type: TransactionType.withdraw,
      );
      await openSheet(tester, s);
      expect(find.text('Save payment').hitTestable(), findsOneWidget);
      expect(amountField.hitTestable(), findsOneWidget);
      await tester.ensureVisible(find.text('Food & Dining'));
      expect(find.text('Food & Dining').hitTestable(), findsOneWidget);
      await typeAmount(tester, '9');
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();
      expect(await countExpenses(s.db), 2);
    },
  );

  testWidgets('the Save payment label has the button text color', (
    tester,
  ) async {
    await openSheet(tester, await testServices());
    await typeAmount(tester, '5');
    await tester.pumpAndSettle();
    final label = find.text('Save payment');
    final color = tester
        .widget<RichText>(
          find.descendant(of: label, matching: find.byType(RichText)),
        )
        .text
        .style!
        .color;
    expect(color, Theme.of(tester.element(label)).colorScheme.onPrimary);
  });

  testWidgets('an edit shows no recent shops', (tester) async {
    final s = await testServices();
    final id = await addOne(s);
    await openSheet(tester, s, expenseId: id);
    expect(find.text('Recent shops'), findsNothing);
  });

  testWidgets(
    'recent shops: three distinct chips, a tap fills Shop and its last category',
    (tester) async {
      final s = await testServices();
      Future<void> add(String shop, String? cat, int day) =>
          s.expenses.addManualExpense(
            amount: Decimal.parse('5.00'),
            merchant: shop,
            postTime: DateTime(2026, 11, day, 12).millisecondsSinceEpoch,
            categoryId: cat,
            notes: null,
            type: TransactionType.withdraw,
          );
      await add('Old Shop', 'other', 1);
      await add('Grab', 'transport', 5);
      await add('Mamak Corner', 'food', 8);
      await add('grab', 'transport', 9);
      await add('7-Eleven', 'shopping', 10);
      await openSheet(tester, s);
      expect(find.text('Recent shops'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, '7-Eleven'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'grab'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Mamak Corner'), findsOneWidget);
      expect(find.widgetWithText(ChoiceChip, 'Old Shop'), findsNothing);
      await tester.ensureVisible(
        find.widgetWithText(ChoiceChip, 'Mamak Corner'),
      );
      await tester.tap(find.widgetWithText(ChoiceChip, 'Mamak Corner'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).controller!.text,
        'Mamak Corner',
      );
      expect(
        tester
            .widget<ChoiceChip>(
              find.widgetWithText(ChoiceChip, 'Food & Dining'),
            )
            .selected,
        true,
      );
    },
  );

  testWidgets('the date picker offers no day after today', (tester) async {
    // A tall view: the chips leave no room for the Date row on the default one.
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    'Count in group totals shows for a spend when the person is in a group',
    (tester) async {
      final backend = FakeBackend();
      backend.on('POST', '/auth/v1/token', tokenReply);
      backend.on(
        'GET',
        '/rest/v1/profiles',
        (r) => jsonReply([
          {'alias': 'Ali'},
        ]),
      );
      backend.on('GET', '/rest/v1/join_requests', (r) => jsonReply([]));
      backend.on(
        'GET',
        '/rest/v1/groups',
        (r) => jsonReply([
          {
            'id': 'g1',
            'name': 'Makan Group',
            'code': 'GRP-AB12',
            'owner_id': 'user-1',
            'group_members': [
              {'user_id': 'user-1'},
            ],
          },
        ]),
      );
      backend.on('GET', '/rest/v1/removed_notices', (r) => jsonReply([]));
      final s = await testServices(
        http: backend.client,
        secrets: {
          'device_token': 'test-device-token',
          'group_session': storedSession,
        },
      );
      await s.online.groups.refresh();
      expect(s.inGroups.value, true);

      await openSheet(tester, s);
      await typeAmount(tester, '8');
      final row = find.text('Count in group totals');
      await tester.ensureVisible(row);
      await tester.pumpAndSettle();
      expect(row, findsOneWidget);
      expect(
        find.text('Group members see this in your totals'),
        findsOneWidget,
      );
      await tester.tap(row);
      await tester.pump();
      expect(
        find.text('Group members do not see this payment'),
        findsOneWidget,
      );
      await tester.tap(find.text('Save payment'));
      await tester.pumpAndSettle();

      final saved = (await s.db.select(s.db.expenses).get()).single;
      expect(saved.privateToGroups, true);
    },
  );

  testWidgets(
    'the payment sheet meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final id = await addOne(s);
      await openSheet(tester, s, expenseId: id, textScale: 1.3);
      await tester.tap(amountField);
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
    await typeAmount(tester, '7');
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
    await typeAmount(tester, '7');
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
        paymentApps: base.paymentApps,
        captureHost: base.captureHost,
        device: base.device,
        online: base.online,
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
  Future<Undoable?> dismissExpense(String id) async {
    await gate.future;
    return super.dismissExpense(id);
  }
}
