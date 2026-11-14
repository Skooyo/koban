import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/screens/activity/activity_view_model.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/activity/activity_screen.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';

Future<void> pay(
  AppServices s,
  String amount,
  DateTime at, {
  String category = 'food',
  String merchant = 'RESTORAN CONTOH',
  TransactionType type = TransactionType.withdraw,
}) => s.expenses.addManualExpense(
  amount: Decimal.parse(amount),
  merchant: merchant,
  postTime: at.millisecondsSinceEpoch,
  categoryId: category,
  notes: null,
  type: type,
);

/// Pumps the app on the Activity tab. The harness drops the tree at the end.
Future<void> pumpActivity(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
}) async {
  // A tall screen, so the lazy list builds all rows.
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(tester, s, textScale: textScale);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Activity'));
  await tester.pumpAndSettle();
}

Finder inActivity(Finder f) =>
    find.descendant(of: find.byType(ActivityScreen), matching: f);

void main() {
  testWidgets('payments show by day under Today, Yesterday and the date', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '7.00', DateTime(2026, 11, 12, 9), merchant: 'Kedai Contoh');
    await pay(s, '3.00', DateTime(2026, 11, 10, 9), merchant: 'Kedai Ali');
    await pumpActivity(tester, s);
    expect(inActivity(find.text('Today')), findsOneWidget);
    expect(inActivity(find.text('Yesterday')), findsOneWidget);
    expect(inActivity(find.text('Tue, 10 Nov')), findsOneWidget);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('Kedai Contoh'), findsOneWidget);
    expect(find.text('Kedai Ali'), findsOneWidget);
    // The chart card: the label and the total of the month.
    expect(find.text('Spent'), findsOneWidget);
    // The chart card holds the total of the month. The week chip has the same amount.
    final card = find
        .ancestor(of: find.text('Spent'), matching: find.byType(Container))
        .first;
    expect(
      find.descendant(of: card, matching: find.text('RM 15.00')),
      findsOneWidget,
    );
  });

  testWidgets('a week chip shows Spent with the week dates', (tester) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '3.00', DateTime(2026, 11, 2, 9), merchant: 'Kedai Ali');
    await pumpActivity(tester, s);
    expect(find.text('Whole month'), findsOneWidget);
    await tester.tap(find.text('9 Nov – 15 Nov'));
    await tester.pumpAndSettle();
    expect(find.text('Spent, 9 Nov – 15 Nov'), findsOneWidget);
    expect(find.text('Kedai Ali'), findsNothing);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    // The strip scrolled to the chosen week. Scroll back to the first chip.
    await tester.ensureVisible(find.text('Whole month'));
    await tester.tap(find.text('Whole month'));
    await tester.pumpAndSettle();
    expect(find.text('Spent'), findsOneWidget);
    expect(find.text('Kedai Ali'), findsOneWidget);
  });

  testWidgets('This week on Home opens Activity on the current week', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();
    expect(
      tester.state<HomeShellState>(find.byType(HomeShell)).tab,
      KobanTab.activity,
    );
    expect(find.text('Spent, 9 Nov – 15 Nov'), findsOneWidget);
  });

  testWidgets('an empty month says No payments in November 2026.', (
    tester,
  ) async {
    await pumpActivity(tester, await testServices());
    expect(find.text('No payments in November 2026.'), findsOneWidget);
    await tester.tap(find.text('9 Nov – 15 Nov'));
    await tester.pumpAndSettle();
    expect(find.text('No payments in this week.'), findsOneWidget);
  });

  testWidgets('Next month is off at the current month', (tester) async {
    await pumpActivity(tester, await testServices());
    IconButton button(String tip) => tester.widget<IconButton>(
      find
          .ancestor(of: find.byTooltip(tip), matching: find.byType(IconButton))
          .first,
    );
    expect(find.text('November 2026'), findsOneWidget);
    expect(button('Next month').onPressed, isNull);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('No payments in October 2026.'), findsOneWidget);
    expect(button('Next month').onPressed, isNotNull);
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });

  testWidgets('the month sheet picks a month', (tester) async {
    final s = await testServices();
    await pay(s, '4.00', DateTime(2026, 9, 13, 9), merchant: 'Kedai Ali');
    await pumpActivity(tester, s);
    await tester.tap(find.text('November 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a month'), findsOneWidget);
    expect(find.text('September 2026'), findsOneWidget);
    await tester.tap(find.text('September 2026'));
    await tester.pumpAndSettle();
    expect(find.text('Pick a month'), findsNothing);
    expect(find.text('Kedai Ali'), findsOneWidget);
  });

  testWidgets('the category sheet filters the list and the chip clears it', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(
      s,
      '7.00',
      DateTime(2026, 11, 12, 9),
      category: 'transport',
      merchant: 'Kedai Contoh',
    );
    final semantics = tester.ensureSemantics();
    await pumpActivity(tester, s);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    expect(find.text('Show one category'), findsOneWidget);
    expect(find.text('All categories'), findsOneWidget);
    // 5 categories and Uncategorized have no spending in the month.
    expect(find.bySemanticsLabel(RegExp('No spending')), findsNWidgets(6));
    await tester.tap(find.text('Food & Dining'));
    await tester.pumpAndSettle();
    expect(find.text('Show one category'), findsNothing);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('Kedai Contoh'), findsNothing);
    final chip = find.bySemanticsLabel(
      'Filtered by Food & Dining. Clear filter',
    );
    expect(chip, findsOneWidget);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('Kedai Contoh'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('the All view shows a header for each month', (tester) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '4.00', DateTime(2026, 10, 13, 9), merchant: 'Kedai Ali');
    await pumpActivity(tester, s);
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('Kedai Ali'), findsOneWidget);
    // The month bar is only in the Month view.
    expect(find.byTooltip('Next month'), findsNothing);
  });

  testWidgets('the All view says No payments yet. with no payment', (
    tester,
  ) async {
    await pumpActivity(tester, await testServices());
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('No payments yet.'), findsOneWidget);
  });

  testWidgets('a tap on a payment opens it in the payment sheet', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pumpActivity(tester, s);
    await tester.tap(find.text('RESTORAN CONTOH'));
    await tester.pumpAndSettle();
    expect(find.text('Payment'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('Add payment opens the payment sheet', (tester) async {
    await pumpActivity(tester, await testServices());
    await tester.tap(inActivity(find.text('Add payment')));
    await tester.pumpAndSettle();
    expect(find.text('Save payment'), findsOneWidget);
  });

  testWidgets('Activity meets the tap target guidelines', (tester) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(s, '50.00', DateTime(2026, 10, 13, 9), merchant: 'Kedai Ali');
    await pumpActivity(tester, s);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('Activity works at text scale 1.3', (tester) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pumpActivity(tester, s, textScale: 1.3);
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food & Dining'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a week over the month edge shows its dates and its total', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '9.00', DateTime(2026, 10, 30, 9), merchant: 'Kedai Ali');
    await pay(s, '2.00', DateTime(2026, 11, 1, 9));
    await pumpActivity(tester, s);
    await tester.tap(find.text('26 Oct – 1 Nov'));
    await tester.pumpAndSettle();
    expect(find.text('Spent, 26 Oct – 1 Nov'), findsOneWidget);
    final card = find
        .ancestor(
          of: find.text('Spent, 26 Oct – 1 Nov'),
          matching: find.byType(Container),
        )
        .first;
    expect(
      find.descendant(of: card, matching: find.text('RM 11.00')),
      findsOneWidget,
    );
    expect(find.text('Kedai Ali'), findsOneWidget);
  });

  testWidgets('the day labels follow the clock after midnight', (tester) async {
    final s = await testServices();
    var time = DateTime(2026, 11, 13, 12);
    final moving = AppServices(
      db: s.db,
      settings: s.settings,
      importResult: s.importResult,
      listener: s.listener,
      paymentApps: s.paymentApps,
      captureHost: s.captureHost,
      device: s.device,
      online: s.online,
      now: () => time,
    );
    await pay(moving, '5.00', DateTime(2026, 11, 13, 9));
    await pumpActivity(tester, moving);
    expect(inActivity(find.text('Today')), findsOneWidget);
    expect(inActivity(find.text('Yesterday')), findsNothing);
    time = DateTime(2026, 11, 14, 0, 30);
    // A new payment makes the view model tell the screen.
    await pay(moving, '7.00', time, merchant: 'Kedai Ali');
    await tester.pumpAndSettle();
    expect(inActivity(find.text('Today')), findsOneWidget);
    expect(inActivity(find.text('Yesterday')), findsOneWidget);
  });

  testWidgets(
    'the month header at scale 1.3 fits its height and clears the list',
    (tester) async {
      final s = await testServices();
      await pay(s, '5.00', DateTime(2026, 9, 13, 9));
      await pay(
        s,
        '50.00',
        DateTime(2026, 9, 14, 9),
        merchant: 'Kedai Ali',
        type: TransactionType.receive,
      );
      await pumpActivity(tester, s, textScale: 1.3);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('+ RM 50.00 received'), findsOneWidget);
      final title = find.text('September 2026');
      final box = tester.getRect(
        find.ancestor(of: title, matching: find.byType(ColoredBox)).first,
      );
      final content = tester.getRect(
        find.ancestor(of: title, matching: find.byType(Padding)).first,
      );
      final group = ActivityMonthGroup(
        const YearMonth(2026, 9),
        Decimal.parse('5'),
        Decimal.parse('50'),
        const [],
      );
      final extent = monthHeaderExtent(
        tester.element(find.byType(ActivityScreen)),
        group,
      );
      expect(box.height, extent);
      // The text fits in the box, and the first row starts below it.
      expect(content.bottom, lessThanOrEqualTo(box.bottom));
      expect(
        tester.getRect(find.text('RESTORAN CONTOH')).top,
        greaterThanOrEqualTo(box.bottom),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
