import 'package:flutter/semantics.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/check/check_payment_card.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'check_payments_view_model_test.dart'
    show addCard, addThreeCards, cardTime, maeDevice;

const firstText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';

/// A page with one button that opens Check payments.
class Opener extends StatelessWidget {
  const Opener({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () => openCheckPayments(context),
        child: const Text('Open check'),
      ),
    ),
  );
}

/// Services with the MAE device channel and the three cards of the tests.
Future<AppServices> threeCards() async {
  final s = await testServices(device: maeDevice());
  await addThreeCards(s);
  return s;
}

/// Pumps the app on a phone-sized screen and opens Check payments.
Future<void> openCheck(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(411, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpKoban(tester, s, home: const Opener(), textScale: textScale);
  await tester.tap(find.text('Open check'));
  await tester.pumpAndSettle();
}

Finder get saveButton => find.widgetWithText(FilledButton, 'Save payment');
Finder get dropButton => find.widgetWithText(OutlinedButton, 'Not a payment');

Future<List<String?>> expenseShops(AppServices s) async => [
  for (final e in await s.db.select(s.db.expenses).get()) e.merchant,
];

Future<List<String>> cardIds(AppServices s) async => [
  for (final p in await s.db.select(s.db.pendingPayments).get()) p.id,
];

/// Ends the 4-second hold on the fake clock and lets the commit run.
Future<void> endHold(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 4));
  await tester.pumpAndSettle();
}

/// The labels of the custom screen reader actions of the top card.
List<String> cardActions(WidgetTester tester) {
  final node = tester.getSemantics(find.byType(CheckPaymentCard).last);
  return [
    for (final id in node.getSemanticsData().customSemanticsActionIds ?? [])
      CustomSemanticsAction.getAction(id)!.label!,
  ];
}

void main() {
  testWidgets('the oldest card is on top with its counter', (tester) async {
    await openCheck(tester, await threeCards());
    expect(find.text('Check payments'), findsOneWidget);
    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('MAE · 12:00'), findsOneWidget);
    expect(find.text('RM 15.00'), findsOneWidget);
    expect(find.text('Today, 12:00'), findsOneWidget);
    expect(find.text('“$firstText”'), findsOneWidget);
    expect(
      find.text(
        'Tap a field to fix it. Swipe right to save, left for Not a payment.',
      ),
      findsOneWidget,
    );
    expect(saveButton, findsOneWidget);
    expect(dropButton, findsOneWidget);
    // The stack has 3 cards. The received card shows its amount with a plus.
    expect(find.byType(CheckPaymentCard), findsNWidgets(3));
    expect(find.text('+ RM 50.00'), findsOneWidget);
    // The stamps show only during a drag.
    expect(find.text('Save'), findsNothing);
  });

  testWidgets('Save payment saves the top card after the Undo window', (
    tester,
  ) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('MAE · 12:00'), findsNothing);
    expect(await expenseShops(s), isEmpty);
    await endHold(tester);
    expect(await expenseShops(s), ['RESTORAN CONTOH']);
    expect(await cardIds(s), unorderedEquals(['card1', 'card2']));
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsNothing);
  });

  testWidgets('Not a payment drops the top card', (tester) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(dropButton);
    await tester.pumpAndSettle();
    expect(find.text('Skipped RESTORAN CONTOH · Undo'), findsOneWidget);
    await endHold(tester);
    expect(await expenseShops(s), isEmpty);
    expect(await cardIds(s), unorderedEquals(['card1', 'card2']));
    final drops = await s.db.select(s.db.droppedNotifications).get();
    expect([for (final d in drops) d.notificationKey], ['key0@$cardTime']);
  });

  testWidgets('a drag past 100 dp saves and a shorter drag springs back', (
    tester,
  ) async {
    await openCheck(tester, await threeCards());
    final start = tester.getTopLeft(find.text('MAE · 12:00'));
    await tester.drag(find.text('MAE · 12:00'), const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsNothing);
    expect(tester.getTopLeft(find.text('MAE · 12:00')), start);
    await tester.drag(find.text('MAE · 12:00'), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('a drag to the left past 100 dp drops the card', (tester) async {
    await openCheck(tester, await threeCards());
    await tester.drag(find.text('MAE · 12:00'), const Offset(-150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Skipped RESTORAN CONTOH · Undo'), findsOneWidget);
  });

  testWidgets('Undo brings the card back', (tester) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Saved RESTORAN CONTOH · Undo'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('MAE · 12:00'), findsOneWidget);
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsNothing);
    await endHold(tester);
    expect(await expenseShops(s), isEmpty);
    expect(await cardIds(s), hasLength(3));
  });

  testWidgets('the Save payment text has the dark text color on gold', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText: firstText,
    );
    await openCheck(tester, s);
    final onPrimary = Theme.of(tester.element(find.text('Save payment')))
        .colorScheme
        .onPrimary;
    final paragraph = tester.renderObject<RenderParagraph>(
      find.text('Save payment'),
    );
    expect(paragraph.text.style!.color, onPrimary);
  });

  testWidgets('a tap on Received switches a known direction on the card', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText: firstText,
    );
    await openCheck(tester, s);
    await tester.tap(find.text('Received'));
    await tester.pumpAndSettle();
    expect(find.text('Change payment'), findsNothing);
    expect(find.text('+ RM 15.00'), findsOneWidget);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    await endHold(tester);
    final saved = await s.db.select(s.db.expenses).get();
    expect(
      [for (final e in saved) e.transactionType],
      [TransactionType.receive],
    );
  });

  testWidgets(
    'a card with no clear direction asks for Spent or Received first',
    (tester) async {
      final s = await testServices(device: maeDevice());
      await addCard(
        s,
        order: 0,
        amount: '15.00',
        merchant: 'RESTORAN CONTOH',
        rawText: firstText,
        directionUnclear: true,
      );
      await openCheck(tester, s);
      expect(find.text('Spent or Received?'), findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Choose Spent or Received first.'), findsOneWidget);
      expect(find.text('Saved RESTORAN CONTOH · Undo'), findsNothing);
      await endHold(tester);
      expect(await expenseShops(s), isEmpty);
      expect(await cardIds(s), ['card0']);

      await tester.tap(find.text('Spent'));
      await tester.pumpAndSettle();
      expect(find.text('Spent or Received?'), findsNothing);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('Saved RESTORAN CONTOH · Undo'), findsOneWidget);
      await endHold(tester);
      final saved = await s.db.select(s.db.expenses).get();
      expect(
        [for (final e in saved) e.transactionType],
        [TransactionType.withdraw],
      );
    },
  );

  testWidgets('a card with no clear direction can still be dropped', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText: firstText,
      directionUnclear: true,
    );
    await openCheck(tester, s);
    await tester.tap(dropButton);
    await tester.pumpAndSettle();
    expect(find.text('Skipped RESTORAN CONTOH · Undo'), findsOneWidget);
    await endHold(tester);
    expect(await cardIds(s), isEmpty);
    expect(await s.db.select(s.db.droppedNotifications).get(), hasLength(1));
  });

  testWidgets('leaving the app commits the held swipe at once', (tester) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(await expenseShops(s), isEmpty);
    // The friend presses Home inside the 4-second window.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final saved = await s.db.select(s.db.expenses).get();
    expect(
      [for (final e in saved) (e.merchant, e.amount.toString())],
      [('RESTORAN CONTOH', '15')],
    );
    expect(await cardIds(s), unorderedEquals(['card1', 'card2']));
    // The app comes back. The saved card does not show again.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.text('MAE · 12:00'), findsNothing);
    expect(find.text('Saved RESTORAN CONTOH · Undo'), findsNothing);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('RM 8.00'), findsOneWidget);
  });

  testWidgets('leaving the app from another page commits the held swipe', (
    tester,
  ) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    // Back closes the screen. The screen commits the swipe when it goes.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Open check'), findsOneWidget);
    expect(await expenseShops(s), ['RESTORAN CONTOH']);
    // A hold that a screen did not commit: the app commits it when it goes to the background.
    s.paymentChecks.hold('card1', save: true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump(const Duration(milliseconds: 100));
    expect(await expenseShops(s), ['RESTORAN CONTOH', 'Kedai Contoh']);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'the last card shows All checked and the screen closes after the pill',
    (tester) async {
      final s = await testServices(device: maeDevice());
      await addCard(
        s,
        order: 0,
        amount: '15.00',
        merchant: 'RESTORAN CONTOH',
        rawText: firstText,
      );
      await openCheck(tester, s);
      expect(find.text('1 of 1'), findsOneWidget);
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(find.text('All checked'), findsOneWidget);
      expect(
        find.text('Nothing left. I will just sit here and shine.'),
        findsOneWidget,
      );
      expect(find.text('Back to Home'), findsOneWidget);
      expect(find.text('Saved RESTORAN CONTOH · Undo'), findsOneWidget);
      expect(find.text('Check payments'), findsOneWidget);
      await endHold(tester);
      expect(find.text('Check payments'), findsNothing);
      expect(find.text('Open check'), findsOneWidget);
      expect(await expenseShops(s), ['RESTORAN CONTOH']);
    },
  );

  testWidgets('a tap on the shop opens Change payment and saves the edit', (
    tester,
  ) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(find.text('RESTORAN CONTOH'));
    await tester.pumpAndSettle();
    expect(find.text('Change payment'), findsOneWidget);
    expect(find.text('Amount (RM)'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Shop'),
      'RESTORAN BARU',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Amount (RM)'), '');
    await tester.pump();
    expect(find.text('Type an amount above 0'), findsOneWidget);
    await tester.enterText(
      find.widgetWithText(TextField, 'Amount (RM)'),
      '16.50',
    );
    await tester.pump();
    await tester.tap(find.text('Save changes'));
    await tester.pumpAndSettle();
    expect(find.text('Change payment'), findsNothing);
    expect(find.text('RESTORAN BARU'), findsOneWidget);
    expect(find.text('RM 16.50'), findsOneWidget);
    final row = await (s.db.select(
      s.db.pendingPayments,
    )..where((t) => t.id.equals('card0'))).getSingle();
    expect(
      (row.merchant, row.amount.toString(), row.edited),
      ('RESTORAN BARU', '16.5', true),
    );
  });

  testWidgets('a swipe down or Back with changes asks Discard changes?', (
    tester,
  ) async {
    final s = await threeCards();
    await openCheck(tester, s);
    await tester.tap(find.text('RESTORAN CONTOH'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Shop'),
      'RESTORAN BARU',
    );
    await tester.pump();
    await tester.fling(find.text('Change payment'), const Offset(0, 500), 2000);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    expect(find.text('Change payment'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(find.text('Change payment'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Change payment'), findsNothing);
    expect(find.text('RESTORAN CONTOH'), findsOneWidget);
    final row = await (s.db.select(
      s.db.pendingPayments,
    )..where((t) => t.id.equals('card0'))).getSingle();
    expect(row.merchant, 'RESTORAN CONTOH');
  });

  testWidgets('screen readers get Save and Not a payment as card actions', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final s = await testServices(device: maeDevice());
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText: firstText,
      directionUnclear: true,
    );
    await addCard(
      s,
      order: 1,
      amount: '8.00',
      merchant: 'Kedai Contoh',
      rawText: 'x',
    );
    await openCheck(tester, s);
    // No Save while the direction is unclear.
    expect(cardActions(tester), ['Not a payment']);
    // The top card is the last in the tree.
    await tester.tap(find.text('Spent').last);
    await tester.pumpAndSettle();
    expect(cardActions(tester), unorderedEquals(['Save', 'Not a payment']));

    final node = tester.getSemantics(find.byType(CheckPaymentCard).last);
    node.owner!.performAction(
      node.id,
      SemanticsAction.customAction,
      CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Not a payment'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Skipped RESTORAN CONTOH · Undo'), findsOneWidget);
    handle.dispose();
  });

  testWidgets(
    'Check payments meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      await openCheck(tester, await threeCards(), textScale: 1.3);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('Home shows the waiting count and opens Check payments', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = await threeCards();
    await pumpKoban(tester, s);
    await tester.pumpAndSettle();
    expect(find.text('3 payments to check'), findsOneWidget);
    // A friend with payments to check does not see the first-payment card.
    expect(find.text('Waiting for your first payment'), findsNothing);
    await tester.tap(find.text('3 payments to check'));
    await tester.pumpAndSettle();
    expect(find.text('Check payments'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await (s.db.delete(
      s.db.pendingPayments,
    )..where((t) => t.id.isIn(['card1', 'card2']))).go();
    await tester.pumpAndSettle();
    expect(find.text('1 payment to check'), findsOneWidget);
  });
}
