import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/home_shell.dart';
import 'package:koban/capture/listener_control.dart';
import 'package:koban/data/legacy_import.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'check_payments_view_model_test.dart' show addCard, addThreeCards;

Future<void> pay(
  AppServices s,
  String amount,
  DateTime at, {
  TransactionType type = TransactionType.withdraw,
  String merchant = 'Kedai Contoh',
  String categoryId = 'food',
}) => s.expenses.addManualExpense(
  amount: Decimal.parse(amount),
  merchant: merchant,
  postTime: at.millisecondsSinceEpoch,
  categoryId: categoryId,
  notes: null,
  type: type,
);

/// A listener with the access answer [granted].
FakeChannel listenerWith({required bool granted}) =>
    FakeChannel(ListenerControl.channelName, {'isAccessGranted': granted});

/// Pumps Home. At the end the tree goes first, so the streams end before the database closes.
Future<void> pumpHome(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
  bool tall = true,
}) async {
  if (tall) {
    // A tall screen, so the lazy list builds all rows.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }
  await pumpKoban(tester, s, textScale: textScale);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Home shows the date and the three totals', (tester) async {
    final s = await testServices();
    await pay(s, '12.50', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s);
    for (final t in [
      'Fri, 13 Nov',
      'Spent today',
      'RM 12.50',
      'Spent this week',
      'Mon 9 Nov – Sun 15 Nov',
      'This month',
      'November 2026',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
  });

  testWidgets('with no payment today Home says so', (tester) async {
    await pumpHome(tester, await testServices());
    expect(find.text('No payments yet today.'), findsOneWidget);
    expect(find.text('RM 0.00'), findsNWidgets(2));
  });

  testWidgets('money received today shows under the total', (tester) async {
    final s = await testServices();
    await pay(
      s,
      '50.00',
      DateTime(2026, 11, 13, 10),
      type: TransactionType.receive,
    );
    await pumpHome(tester, s);
    expect(find.text('+ RM 50.00 received'), findsOneWidget);
    expect(find.text('No payments yet today.'), findsNothing);
    // The month row and the payment row.
    expect(find.text('+ RM 50.00'), findsNWidgets(2));
  });

  testWidgets(
    'tracking off shows the banner and Turn on opens the access settings',
    (tester) async {
      final listener = listenerWith(granted: false);
      await pumpHome(tester, await testServices(listener: listener));
      expect(find.text('Tracking is off'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await tester.pump();
      expect(
        listener.calls.map((c) => c.method),
        contains('openAccessSettings'),
      );
    },
  );

  testWidgets('the first payment card shows only with access and no payment', (
    tester,
  ) async {
    await pumpHome(tester, await testServices());
    expect(find.text('Waiting for your first payment'), findsOneWidget);
    expect(find.text('Pay for anything. It shows up here.'), findsOneWidget);
    expect(find.text('Add one by hand'), findsOneWidget);
  });

  testWidgets('a payment hides the first payment card', (tester) async {
    final s = await testServices();
    await pay(s, '5.00', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s);
    expect(find.text('Waiting for your first payment'), findsNothing);
  });

  testWidgets('no access hides the first payment card', (tester) async {
    await pumpHome(
      tester,
      await testServices(listener: listenerWith(granted: false)),
    );
    expect(find.text('Waiting for your first payment'), findsNothing);
  });

  testWidgets('a failed import shows that the data is safe', (tester) async {
    final s = await testServices(
      importResult: const ImportFailed(['owed_items'], 'x'),
    );
    await pumpHome(tester, s);
    expect(find.text(importFailedMessage), findsOneWidget);
  });

  testWidgets(
    'Latest this week shows at most 5 payments with the day and time',
    (tester) async {
      final s = await testServices();
      for (var i = 0; i < 6; i++) {
        await pay(
          s,
          '${i + 1}.00',
          DateTime(2026, 11, 13, 12),
          merchant: 'Kedai $i',
        );
      }
      await pumpHome(tester, s);
      expect(find.text('Latest this week'), findsOneWidget);
      expect(find.textContaining('Kedai '), findsNWidgets(5));
      expect(find.text('Fri 12:00 · Food & Dining'), findsNWidgets(5));
    },
  );

  testWidgets(
    'This week sets the Activity selection to the current week and selects the Activity tab',
    (tester) async {
      final s = await testServices();
      await pumpHome(tester, s);
      await tester.tap(find.text('Spent this week'));
      await tester.pump();
      expect(
        s.activitySelection.value.weekStart,
        DateTime(2026, 11, 9).millisecondsSinceEpoch,
      );
      expect(
        tester.state<HomeShellState>(find.byType(HomeShell)).tab,
        KobanTab.activity,
      );
    },
  );

  testWidgets('the waiting row sums the Spent payments in the review color', (
    tester,
  ) async {
    final s = await testServices();
    await addThreeCards(s);
    await pumpHome(tester, s);
    expect(find.text('3 payments to check'), findsOneWidget);
    // RM 15.00 + RM 8.00. The RM 50.00 received is not in the sum.
    expect(find.text('RM 23.00 found, not saved yet'), findsOneWidget);
    final icon = tester.widget<Icon>(find.byIcon(Icons.receipt).first);
    expect(
      icon.color,
      MoneyColors.of(tester.element(find.byIcon(Icons.receipt).first)).review,
    );
  });

  testWidgets('the waiting row with no Spent payment has no sum', (
    tester,
  ) async {
    final s = await testServices();
    await addCard(
      s,
      order: 0,
      amount: '50.00',
      merchant: 'ALI',
      type: TransactionType.receive,
      rawText: 'ALI has transferred RM 50.00 to you.',
    );
    await pumpHome(tester, s);
    expect(find.text('1 payment to check'), findsOneWidget);
    expect(find.text('Found by Koban, not saved yet'), findsOneWidget);
  });

  testWidgets('a tap on Spent today opens the week', (tester) async {
    final s = await testServices();
    await pay(s, '12.50', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s);
    await tester.tap(find.text('Spent today'));
    await tester.pump();
    expect(
      s.activitySelection.value.weekStart,
      DateTime(2026, 11, 9).millisecondsSinceEpoch,
    );
    expect(
      tester.state<HomeShellState>(find.byType(HomeShell)).tab,
      KobanTab.activity,
    );
  });

  testWidgets('Add payment saves a payment and Home says Payment saved', (
    tester,
  ) async {
    final s = await testServices();
    await pumpHome(tester, s);
    await tester.tap(find.text('Add payment'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '12.5');
    await tester.pump();
    await tester.tap(find.text('Save payment'));
    await tester.pumpAndSettle();
    expect(find.text('Payment saved'), findsOneWidget);
    expect(find.text('RM 12.50'), findsWidgets);
    expect(find.text('No payments yet today.'), findsNothing);
  });

  testWidgets('a resume reads the access again', (tester) async {
    final listener = listenerWith(granted: false);
    await pumpHome(tester, await testServices(listener: listener));
    expect(find.text('Tracking is off'), findsOneWidget);
    listener.answers['isAccessGranted'] = true;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('Tracking on'), findsOneWidget);
    expect(find.text('Tracking is off'), findsNothing);
  });

  testWidgets('Mon says Tracking on in the bubble, and no card', (
    tester,
  ) async {
    await pumpHome(tester, await testServices());
    expect(find.text('Tracking on'), findsOneWidget);
    expect(find.text('Turn on'), findsNothing);
  });

  testWidgets('the payments to check row comes before the week card', (
    tester,
  ) async {
    final s = await testServices();
    await addThreeCards(s);
    await pumpHome(tester, s);
    expect(
      tester.getTopLeft(find.text('3 payments to check')).dy,
      lessThan(tester.getTopLeft(find.text('Spent this week')).dy),
    );
    expect(find.textContaining(' to check'), findsOneWidget);
  });

  testWidgets('with limits, This month says spent of limit and N over', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '120.00', DateTime(2026, 11, 13, 9));
    await pay(
      s,
      '30.00',
      DateTime(2026, 11, 13, 10),
      merchant: 'Bus',
      categoryId: 'transport',
    );
    await s.budgets.setLimit('food', Decimal.parse('100'));
    await pumpHome(tester, s);
    expect(find.text('Budgets: RM 120.00 of RM 100.00'), findsOneWidget);
    // The month total stays on the row.
    expect(
      find.descendant(
        of: find.widgetWithText(KobanRow, 'This month'),
        matching: find.text('RM 150.00'),
      ),
      findsOneWidget,
    );
    final over = find.text('1 over');
    expect(over, findsOneWidget);
    expect(
      tester.widget<Text>(over).style!.color,
      Theme.of(tester.element(over)).colorScheme.error,
    );
    await tester.tap(find.text('This month'));
    await tester.pump();
    expect(
      tester.state<HomeShellState>(find.byType(HomeShell)).tab,
      KobanTab.activity,
    );
  });

  testWidgets('spending only in an unbudgeted category is not counted', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '520.00', DateTime(2026, 11, 13, 9), categoryId: 'shopping');
    await s.budgets.setLimit('food', Decimal.parse('100'));
    await pumpHome(tester, s);
    expect(find.text('Budgets: RM 0.00 of RM 100.00'), findsOneWidget);
    expect(find.textContaining(' over'), findsNothing);
  });

  testWidgets('with a limit not reached, there is no over mark', (
    tester,
  ) async {
    final s = await testServices();
    await pay(s, '20.00', DateTime(2026, 11, 13, 9));
    await s.budgets.setLimit('food', Decimal.parse('100'));
    await pumpHome(tester, s);
    expect(find.text('Budgets: RM 20.00 of RM 100.00'), findsOneWidget);
    expect(find.textContaining(' over'), findsNothing);
  });

  testWidgets('with no limits, This month keeps its date line', (tester) async {
    final s = await testServices();
    await pay(s, '20.00', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s);
    expect(find.text('November 2026'), findsOneWidget);
    expect(find.textContaining(' of RM'), findsNothing);
  });

  testWidgets('Home meets the tap target guidelines', (tester) async {
    final s = await testServices();
    await pay(s, '12.50', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('Home works at text scale 1.3', (tester) async {
    final s = await testServices();
    await pay(s, '12.50', DateTime(2026, 11, 13, 9));
    await pumpHome(tester, s, textScale: 1.3);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Add payment label has the gold button text color', (
    tester,
  ) async {
    await pumpHome(tester, await testServices());
    final label = find.text('Add payment');
    final color = tester
        .widget<RichText>(
          find.descendant(of: label, matching: find.byType(RichText)),
        )
        .text
        .style!
        .color;
    expect(
      color,
      Theme.of(tester.element(label)).floatingActionButtonTheme.foregroundColor,
    );
  });
}
