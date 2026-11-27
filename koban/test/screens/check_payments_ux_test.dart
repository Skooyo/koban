import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/rules/types.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import 'check_payments_screen_test.dart'
    show cardIds, endHold, firstText, openCheck, saveButton;
import 'check_payments_view_model_test.dart' show addCard, maeDevice;
import 'home_screen_test.dart' show pumpHome;

const reloadText =
    "Your money is in! RM20.00 has been reloaded to your Touch 'n Go eWallet "
    'balance. Reference No. 2026111500000000000000000000000000001';

Future<void> addOne(
  AppServices s, {
  String rawText = firstText,
  String? merchant = 'RESTORAN CONTOH',
  CaptureFormat format = CaptureFormat.known,
  TransactionType type = TransactionType.withdraw,
}) => addCard(
  s,
  order: 0,
  amount: '15.00',
  merchant: merchant,
  rawText: rawText,
  format: format,
  type: type,
);

void main() {
  testWidgets('a long notification text shows one line until Show full text', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addOne(s, rawText: '$firstText $firstText $firstText');
    await openCheck(tester, s);
    Text raw() => tester.widget<Text>(find.textContaining('REF: QR123456'));
    expect(raw().maxLines, 1);
    await tester.tap(find.text('Show full text'));
    await tester.pumpAndSettle();
    expect(raw().maxLines, null);
    expect(find.text('Show less'), findsOneWidget);
  });

  testWidgets('a short notification text has no Show full text', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addOne(s, rawText: 'Paid RM 15.00');
    await openCheck(tester, s);
    expect(find.text('Show full text'), findsNothing);
  });

  testWidgets('an unknown format says what Koban guessed', (tester) async {
    final s = await testServices(device: maeDevice());
    await addOne(s, format: CaptureFormat.unknown);
    await openCheck(tester, s);
    expect(
      find.textContaining('Koban did not know this message'),
      findsOneWidget,
    );
    expect(find.text('Shop · guessed'), findsOneWidget);
    expect(find.text('Unknown format'), findsNothing);
  });

  testWidgets('a known format has no guess note', (tester) async {
    final s = await testServices(device: maeDevice());
    await addOne(s);
    await openCheck(tester, s);
    expect(find.textContaining('Koban did not know'), findsNothing);
    expect(find.text('Shop · guessed'), findsNothing);
  });

  testWidgets('a top-up says so and Not a payment is the gold button', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addOne(
      s,
      rawText: reloadText,
      merchant: "your Touch 'n Go eWallet balance",
      format: CaptureFormat.unknown,
      type: TransactionType.receive,
    );
    await openCheck(tester, s);
    expect(
      find.text('Looks like a wallet top-up, so usually not a payment.'),
      findsOneWidget,
    );
    expect(find.textContaining('Koban did not know'), findsNothing);
    expect(saveButton, findsNothing);
    expect(find.widgetWithText(OutlinedButton, 'Save payment'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Not a payment'));
    await tester.pumpAndSettle();
    await endHold(tester);
    expect(await cardIds(s), isEmpty);
    expect(await s.db.select(s.db.expenses).get(), isEmpty);
  });

  testWidgets(
    'the category chips show on the card and More opens the sheet with Most used',
    (tester) async {
      final s = await testServices(device: maeDevice());
      // One shop each: a category on a shop also moves that shop's older payments.
      for (final (i, c) in ['transport', 'transport', 'shopping'].indexed) {
        await s.expenses.addManualExpense(
          amount: Decimal.parse('5'),
          merchant: 'KEDAI $i',
          postTime: 1000,
          categoryId: c,
          type: TransactionType.withdraw,
        );
      }
      await addOne(s);
      await openCheck(tester, s);
      expect(find.text('Category · not set'), findsOneWidget);
      expect(find.byType(ChoiceChip), findsNWidgets(4));
      // Most used first: Transport, then Shopping.
      expect(
        [
          for (final c in tester.widgetList<ChoiceChip>(
            find.byType(ChoiceChip),
          ))
            (c.label as Text).data,
        ].take(2),
        ['Transport', 'Shopping'],
      );

      await tester.tap(find.text('More…'));
      await tester.pumpAndSettle();
      expect(find.text('Most used'), findsOneWidget);
      expect(find.text('All categories'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Shopping'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Most used'), findsNothing);
      expect(find.text('Category · not set'), findsNothing);
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Shopping'))
            .selected,
        true,
      );
      await tester.tap(saveButton);
      await tester.pumpAndSettle();
      await endHold(tester);
      final saved = await s.db.select(s.db.expenses).get();
      expect(
        saved.where((e) => e.merchant == 'RESTORAN CONTOH').single.categoryId,
        'shopping',
      );
    },
  );

  testWidgets('a top-up card with a long text fits a 390x844 phone', (
    tester,
  ) async {
    final s = await testServices(device: maeDevice());
    await addOne(
      s,
      rawText: reloadText,
      merchant: "your Touch 'n Go eWallet balance",
      format: CaptureFormat.unknown,
      type: TransactionType.receive,
    );
    await openCheck(tester, s);
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    const screen = Rect.fromLTWH(0, 0, 390, 844);
    // The buttons stay on screen; the long card scrolls above them.
    for (final f in [
      find.widgetWithText(OutlinedButton, 'Save payment'),
      find.widgetWithText(FilledButton, 'Not a payment'),
    ]) {
      final r = tester.getRect(f);
      expect(
        screen.contains(r.topLeft) && screen.contains(r.bottomRight),
        true,
      );
    }
    await tester.ensureVisible(find.text('Show full text'));
    await tester.pumpAndSettle();
    final r = tester.getRect(find.text('Show full text'));
    expect(screen.contains(r.topLeft) && screen.contains(r.bottomRight), true);
  });

  testWidgets('notifications off shows a row and Turn on asks Android again', (
    tester,
  ) async {
    final device = maeDevice()
      ..answers['notificationsAllowed'] = false
      ..answers['requestNotificationPermission'] = true;
    final s = await testServices(device: device);
    await addOne(s);
    await openCheck(tester, s);
    expect(find.text('Koban notifications are off'), findsOneWidget);
    device.answers['notificationsAllowed'] = true;
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(
      device.calls.map((c) => c.method),
      contains('requestNotificationPermission'),
    );
    expect(find.text('Koban notifications are off'), findsNothing);
  });

  testWidgets('after two denials Turn on opens the notification settings', (
    tester,
  ) async {
    final device = maeDevice()
      ..answers['notificationsAllowed'] = false
      ..answers['requestNotificationPermission'] = false
      ..answers['shouldShowNotificationRationale'] = false;
    final s = await testServices(device: device);
    await addOne(s);
    await openCheck(tester, s);
    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(
      device.calls.map((c) => c.method),
      contains('openAppNotificationSettings'),
    );
  });

  testWidgets('Home shows the notifications off row', (tester) async {
    final device = FakeChannel(deviceChannelName, {
      'notificationsAllowed': false,
    });
    await pumpHome(tester, await testServices(device: device));
    expect(find.text('Koban notifications are off'), findsOneWidget);
  });
}
