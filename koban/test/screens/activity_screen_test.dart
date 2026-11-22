import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/rules/periods.dart';
import 'package:koban/screens/activity/activity_view_model.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/activity/activity_screen.dart';
import 'package:koban/theme/mon.dart';
import 'package:koban/ui/kit.dart';
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
  await tester.tap(find.byTooltip('Activity'));
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
    await tester.tap(find.text('Spent this week'));
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
    expect(
      find.text('Add one, or turn on tracking to find them.'),
      findsOneWidget,
    );
    expect(find.byType(Mon), findsOneWidget);
    expect(find.text('Clear filter'), findsNothing);
    await tester.tap(find.text('9 Nov – 15 Nov'));
    await tester.pumpAndSettle();
    expect(find.text('No payments in this week.'), findsOneWidget);
  });

  testWidgets(
    'By category lists the top four by amount, folds the rest, and a tap filters',
    (tester) async {
      final s = await testServices();
      final at = DateTime(2026, 11, 10, 9);
      await pay(s, '20.00', at, merchant: 'Kedai A');
      await pay(s, '20.00', at, merchant: 'Kedai B');
      await pay(s, '10.00', at, merchant: 'Kedai C');
      await pay(s, '15.00', at, category: 'transport', merchant: 'Grab 1');
      await pay(s, '15.00', at, category: 'transport', merchant: 'Grab 2');
      await pay(s, '20.00', at, category: 'shopping', merchant: 'Mall');
      await pay(s, '15.00', at, category: 'bills', merchant: 'Telco');
      await pay(s, '8.00', at, category: 'health', merchant: 'Klinik');
      await pay(s, '5.00', at, category: 'other', merchant: 'Misc');
      // Money received does not count as a payment in the list.
      await pay(s, '99.00', at, merchant: 'Ali', type: TransactionType.receive);
      await pumpActivity(tester, s);

      expect(find.text('By category'), findsOneWidget);
      Finder row(String name) => find.widgetWithText(KobanRow, name);
      Finder inRow(String name, String text) =>
          find.descendant(of: row(name), matching: find.text(text));
      expect(inRow('Food & Dining', '3 payments'), findsOneWidget);
      expect(inRow('Food & Dining', 'RM 50.00'), findsOneWidget);
      expect(inRow('Transport', '2 payments'), findsOneWidget);
      expect(inRow('Transport', 'RM 30.00'), findsOneWidget);
      expect(inRow('Shopping', '1 payment'), findsOneWidget);
      expect(inRow('Bills & Utilities', 'RM 15.00'), findsOneWidget);
      // Health (8.00) and Other (5.00) fold into one row.
      expect(row('Health'), findsNothing);
      expect(inRow('Other categories', '2 payments'), findsOneWidget);
      expect(inRow('Other categories', 'RM 13.00'), findsOneWidget);

      await tester.tap(row('Transport'));
      await tester.pumpAndSettle();
      expect(find.text('Grab 1'), findsOneWidget);
      expect(find.text('Grab 2'), findsOneWidget);
      expect(find.text('Kedai A'), findsNothing);
      expect(find.text('Mall'), findsNothing);
    },
  );

  testWidgets('By category does not show for a month with no payment', (
    tester,
  ) async {
    await pumpActivity(tester, await testServices());
    expect(find.text('By category'), findsNothing);
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

  testWidgets(
    'the category sheet filters the list and All categories clears it',
    (tester) async {
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
      await tester.tap(find.text('Food & Dining').last);
      await tester.pumpAndSettle();
      expect(find.text('Show one category'), findsNothing);
      expect(find.text('RESTORAN CONTOH'), findsOneWidget);
      expect(find.text('Kedai Contoh'), findsNothing);
      // The summary row shows the category, the count and the spent total of the month.
      expect(find.text('1 payment, November 2026'), findsOneWidget);
      expect(find.text('Filter \u00b7 1'), findsOneWidget);
      await tester.tap(find.text('Filter \u00b7 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('All categories'));
      await tester.pumpAndSettle();
      expect(find.text('1 payment, November 2026'), findsNothing);
      expect(find.text('Filter'), findsOneWidget);
      expect(find.text('RESTORAN CONTOH'), findsOneWidget);
      expect(find.text('Kedai Contoh'), findsOneWidget);
      semantics.dispose();
    },
  );

  Finder searchField() => find.widgetWithText(TextField, 'Search shop or note');

  Future<void> searchSeed(AppServices s) async {
    await pay(
      s,
      '18.80',
      DateTime(2026, 11, 13, 8, 15),
      category: 'transport',
      merchant: 'Grab',
    );
    await pay(
      s,
      '11.00',
      DateTime(2026, 11, 12, 9),
      category: 'transport',
      merchant: 'GRAB Food',
    );
    await pay(s, '14.20', DateTime(2026, 11, 11, 9), merchant: 'Mamak Corner');
    await s.expenses.addManualExpense(
      amount: Decimal.parse('6.50'),
      merchant: '7-Eleven',
      postTime: DateTime(2026, 11, 10, 9).millisecondsSinceEpoch,
      categoryId: 'food',
      notes: 'drink for the grab driver',
      type: TransactionType.withdraw,
    );
    await pay(
      s,
      '24.40',
      DateTime(2026, 10, 30, 9),
      category: 'transport',
      merchant: 'Grab',
    );
  }

  testWidgets('search filters by shop or note on the device', (tester) async {
    final s = await testServices();
    await searchSeed(s);
    await pumpActivity(tester, s);
    expect(find.text('Search shop or note'), findsOneWidget);
    expect(find.text('Filter'), findsOneWidget);
    expect(find.text('Mamak Corner'), findsOneWidget);

    await tester.enterText(searchField(), 'grab');
    await tester.pumpAndSettle();

    // Two shops (any case) and one note match. The Mamak payment and October stay out.
    expect(find.text('Grab'), findsOneWidget);
    expect(find.text('GRAB Food'), findsOneWidget);
    expect(find.text('7-Eleven'), findsOneWidget);
    expect(find.text('Mamak Corner'), findsNothing);
    // The summary row: the text, the count and the spent total of the view.
    expect(find.text('"grab"'), findsOneWidget);
    expect(find.text('3 payments, November 2026'), findsOneWidget);
    expect(find.text('RM 36.30'), findsOneWidget);
    // A search alone is not a category filter.
    expect(find.text('Filter'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Mamak Corner'), findsOneWidget);
    expect(find.text('"grab"'), findsNothing);
    expect(tester.widget<TextField>(searchField()).controller!.text, '');
  });

  testWidgets('search and a category filter together, in the All view', (
    tester,
  ) async {
    final s = await testServices();
    await searchSeed(s);
    await pumpActivity(tester, s);
    await tester.enterText(searchField(), 'grab');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();

    // The Filter button counts the category filter. The 7-Eleven note match is Food.
    expect(find.text('Filter \u00b7 1'), findsOneWidget);
    final button = find.ancestor(
      of: find.text('Filter \u00b7 1'),
      matching: find.byType(Material),
    );
    expect(
      tester.widget<Material>(button.first).color,
      Theme.of(tester.element(button.first)).colorScheme.primaryContainer,
    );
    expect(find.text('Transport, "grab"'), findsOneWidget);
    expect(find.text('2 payments, November 2026'), findsOneWidget);
    final summary = find.widgetWithText(KobanRow, 'Transport, "grab"');
    expect(
      find.descendant(of: summary, matching: find.text('RM 29.80')),
      findsOneWidget,
    );
    expect(find.text('7-Eleven'), findsNothing);

    await tester.tap(find.text('All'));
    await tester.pumpAndSettle();
    expect(find.text('Transport, "grab"'), findsOneWidget);
    expect(find.text('3 payments, all months'), findsOneWidget);
    expect(
      find.descendant(of: summary, matching: find.text('RM 54.20')),
      findsOneWidget,
    );
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('the summary count matches the spent total, not received', (
    tester,
  ) async {
    final s = await testServices();
    await searchSeed(s);
    await pay(
      s,
      '5.00',
      DateTime(2026, 11, 9, 9),
      merchant: 'Grab refund',
      type: TransactionType.receive,
    );
    await pumpActivity(tester, s);
    await tester.enterText(searchField(), 'grab');
    await tester.pumpAndSettle();
    expect(find.text('Grab refund'), findsOneWidget);
    expect(find.text('3 payments, November 2026'), findsOneWidget);
    expect(find.text('RM 36.30'), findsOneWidget);
  });

  testWidgets('a search with no match says so and Clear search resets it', (
    tester,
  ) async {
    final s = await testServices();
    await searchSeed(s);
    await pumpActivity(tester, s);
    await tester.enterText(searchField(), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No payments match "zzz".'), findsOneWidget);
    expect(find.text('Try another word, or clear the search.'), findsOneWidget);
    expect(find.text('0 payments, November 2026'), findsOneWidget);
    expect(find.text('RM 0.00'), findsWidgets);
    await tester.tap(find.text('Clear search'));
    await tester.pumpAndSettle();
    expect(find.text('Mamak Corner'), findsOneWidget);
    expect(find.text('No payments match "zzz".'), findsNothing);
  });

  testWidgets('an empty month with a filter offers Clear filter', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pay(
      s,
      '7.00',
      DateTime(2026, 10, 12, 9),
      category: 'transport',
      merchant: 'Kedai Contoh',
    );
    await pumpActivity(tester, s);
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transport').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(
      find.text('No Transport payments in November 2026.'),
      findsOneWidget,
    );
    expect(find.text('Clear the filter to see all payments.'), findsOneWidget);
    expect(find.byType(Mon), findsOneWidget);
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    expect(find.text('Clear filter'), findsNothing);
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
    expect(find.text('Save payment'), findsOneWidget);
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
    await tester.tap(find.text('Food & Dining').last);
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
