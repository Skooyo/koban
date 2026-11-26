import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/user_error.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/person/person_screen.dart';
import 'package:koban/screens/person/person_view_model.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../data/qr_store_test.dart' show pngBytes, wideBytes;
import '../support/harness.dart';
import 'person_view_model_test.dart' show d, day, seedAli;

/// A page with one button. The button opens the person page.
class PersonOpener extends StatefulWidget {
  const PersonOpener(this.personId, {super.key});

  final String personId;

  @override
  State<PersonOpener> createState() => PersonOpenerState();
}

class PersonOpenerState extends State<PersonOpener> {
  bool closed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          await openPerson(context, widget.personId);
          setState(() => closed = true);
        },
        child: const Text('Open person'),
      ),
    ),
  );
}

Future<PersonOpenerState> openPage(
  WidgetTester tester,
  AppServices s,
  String personId, {
  double textScale = 1,
}) async {
  await pumpKoban(
    tester,
    s,
    home: PersonOpener(personId),
    textScale: textScale,
  );
  await tester.tap(find.text('Open person'));
  await settle(tester);
  return tester.state<PersonOpenerState>(
    find.byType(PersonOpener, skipOffstage: false),
  );
}

PersonViewModel vmOf(WidgetTester tester) =>
    tester.state<PersonScreenState>(find.byType(PersonScreen)).viewModel;

Finder inDialog(Finder f) =>
    find.descendant(of: find.byType(AlertDialog), matching: f);

/// Lets the database work end. Its streams need real time in a widget test.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
  }
}

/// Scrolls the person page until [f] is built and on screen.
/// [up] scrolls toward the top.
Future<void> seek(WidgetTester tester, Finder f, {bool up = false}) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      up ? -200 : 200,
      scrollable: find
          .descendant(
            of: find.byType(PersonScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

Future<void> tapIn(WidgetTester tester, Finder f) async {
  await seek(tester, f);
  await tester.tap(f);
  await settle(tester);
}

/// Lets real file work end, until [done] is true.
Future<void> settleReal(WidgetTester tester, bool Function() done) async {
  for (var i = 0; i < 100 && !done(); i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(done(), isTrue);
  await tester.pumpAndSettle();
}

Future<String> debtIdOf(AppServices s, {required bool manual}) async {
  for (final debt in await s.db.select(s.db.splitDebts).get()) {
    final bill = await s.db.bill(debt.billId).getSingle();
    if (bill.manual == manual) return debt.id;
  }
  throw StateError('No debt');
}

void main() {
  testWidgets('the page shows the headline and both sides', (tester) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    // The balance card comes first, with the amount in the received color.
    final amount = find.text('+ RM 30.00');
    expect(amount, findsOneWidget);
    expect(
      tester.widget<Text>(amount).style!.color,
      MoneyColors.of(tester.element(amount)).received,
    );
    expect(
      tester.getTopLeft(amount).dy,
      lessThan(tester.getTopLeft(find.text('Kedai Contoh')).dy),
    );
    expect(find.text('Ali owes you'), findsNWidgets(2));
    expect(find.text('From 2 splits. Oldest: Today.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Send reminder'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Settle up'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Settle up'), findsNothing);
    // The QR is a row, not a box on top of the page.
    await seek(tester, find.text("Ali's payment QR"));
    expect(find.text('Not added yet.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Add QR'), findsOneWidget);
    expect(find.text('Add their payment QR'), findsNothing);
    for (final text in ['Kedai Contoh', 'Cash', 'You owe Ali', 'Parking']) {
      await seek(tester, find.text(text));
      expect(find.text(text), findsOneWidget);
    }
    expect(
      find.descendant(
        of: find.widgetWithText(KobanRow, 'Parking'),
        matching: find.text('13 Nov'),
      ),
      findsOneWidget,
    );
    expect(find.text('Save QR to gallery'), findsNothing);
  });

  testWidgets('a bill you owe shows the owe card with one gold Settle up', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await s.people.addPerson('Ali');
    await s.people.addOwedItem(
      ali,
      'Parking',
      d('4'),
      DateTime(2026, 10, 31, 12).millisecondsSinceEpoch,
    );
    await openPage(tester, s, ali);

    expect(find.text('You owe Ali'), findsNWidgets(2));
    final amount = find.text('RM 4.00');
    // The card amount and the row amount are in ink, not gold.
    final ink = Theme.of(tester.element(amount.first)).colorScheme.onSurface;
    for (final w in tester.widgetList<Text>(amount)) {
      expect(w.style?.color ?? w.textSpan?.style?.color, ink);
    }
    expect(find.text('From 1 split. Oldest: Sat, 31 Oct.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Settle up'), findsOneWidget);
    expect(find.text('Send reminder'), findsNothing);
    expect(find.byType(FilledButton), findsOneWidget);
  });

  testWidgets('Send reminder opens the share sheet with the plain text', (
    tester,
  ) async {
    final device = FakeChannel(deviceChannelName, {'shareText': null});
    final s = await testServices(device: device);
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    await tapIn(tester, find.text('Send reminder'));

    expect(device.calls.single.method, 'shareText');
    expect(device.calls.single.arguments, {
      'text': 'Hi Ali, you owe me RM 30.00 for 2 splits (Koban).',
      'chooserTitle': 'Send reminder',
    });
  });

  testWidgets('Settle up says who pays whom and closes everything', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    await tapIn(tester, find.widgetWithText(OutlinedButton, 'Settle up'));
    expect(inDialog(find.text('Settle up with Ali?')), findsOneWidget);
    expect(inDialog(find.text('+ RM 30.00')), findsOneWidget);
    expect(
      inDialog(
        find.text(
          'Ali pays you RM 30.00. This closes 1 split: Kedai Contoh, 13 Nov; '
          '2 items: Cash, 13 Nov and Parking, 13 Nov. '
          'You cannot change their items after this.',
        ),
      ),
      findsOneWidget,
    );
    await tapIn(tester, inDialog(find.text('Settle up')));

    expect(find.text('All paid'), findsOneWidget);
    await seek(tester, find.text('Add what I owe'));
    expect(find.text('Nothing.'), findsNWidgets(2));
    expect(find.text('Settle up'), findsNothing);
    final debts = await s.db.select(s.db.splitDebts).get();
    expect(debts.map((x) => x.status), [DebtStatus.paid, DebtStatus.paid]);
  });

  testWidgets('add what I owe keeps Save off until the amount is above zero', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    await tapIn(tester, find.widgetWithText(TextButton, 'Add what I owe'));
    expect(inDialog(find.text('Add what I owe')), findsOneWidget);
    expect(inDialog(find.text('Fri, 13 Nov 2026')), findsOneWidget);
    expect(inDialog(find.text('RM ')), findsOneWidget);
    final save = inDialog(find.widgetWithText(TextButton, 'Save'));
    expect(tester.widget<TextButton>(save).onPressed, isNull);

    final amount = inDialog(find.widgetWithText(TextField, 'Amount'));
    await tester.enterText(amount, '0');
    await tester.pump();
    expect(tester.widget<TextButton>(save).onPressed, isNull);
    await tester.enterText(amount, '3.50');
    await tester.pump();
    expect(tester.widget<TextButton>(save).onPressed, isNotNull);
    await tapIn(tester, save);
    expect(inDialog(find.text('Enter what it was for.')), findsOneWidget);

    await tester.enterText(
      inDialog(find.widgetWithText(TextField, 'What for')),
      'Teh',
    );
    await tester.pump();
    expect(find.text('Enter what it was for.'), findsNothing);
    await tapIn(tester, save);

    expect(find.byType(AlertDialog), findsNothing);
    await seek(tester, find.text('Teh'));
    expect(find.text('Teh'), findsOneWidget);
    await seek(tester, find.text('+ RM 26.50'), up: true);
    expect(find.text('+ RM 26.50'), findsOneWidget);
  });

  testWidgets(
    'a manual debt opens its edit dialog and a split debt opens the split',
    (tester) async {
      final s = await testServices();
      final ali = await seedAli(s);
      await openPage(tester, s, ali);

      await tapIn(tester, find.text('Cash'));
      expect(inDialog(find.text('Edit what Ali owes you')), findsOneWidget);
      expect(inDialog(find.text('20.00')), findsOneWidget);
      // Delete sits at the left end of the button row, apart from Save.
      final delete = tester.getTopLeft(inDialog(find.text('Delete'))).dx;
      expect(
        delete,
        lessThan(tester.getTopLeft(inDialog(find.text('Cancel'))).dx),
      );
      await tapIn(tester, inDialog(find.text('Cancel')));

      await tapIn(tester, find.text('Kedai Contoh'));
      expect(find.text('Split'), findsOneWidget);
    },
  );

  testWidgets('Mark paid offers the matching receives and cash', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.expenses.addManualExpense(
      amount: d('14.00'),
      merchant: 'Ali',
      postTime: DateTime(2026, 11, 13, 9).millisecondsSinceEpoch,
      type: TransactionType.receive,
    );
    final splitDebt = await debtIdOf(s, manual: false);
    await openPage(tester, s, ali);

    await tapIn(
      tester,
      find.descendant(
        of: find.byKey(ValueKey(splitDebt)),
        matching: find.widgetWithText(TextButton, 'Mark paid'),
      ),
    );
    expect(inDialog(find.text('Mark RM 14.00 paid')), findsOneWidget);
    expect(
      inDialog(find.text('Kedai Contoh, Fri, 13 Nov. How did Ali pay?')),
      findsOneWidget,
    );
    expect(inDialog(find.text('RM 14.00 received')), findsOneWidget);
    expect(inDialog(find.text('Fri, 13 Nov · Ali')), findsOneWidget);
    expect(inDialog(find.text('Paid in cash')), findsOneWidget);
    // One tap on a choice marks nothing. Mark paid does.
    await tapIn(tester, inDialog(find.text('Paid in cash')));
    expect(find.byType(AlertDialog), findsOneWidget);
    expect((await s.db.debt(splitDebt).getSingle()).status, DebtStatus.open);
    await tapIn(tester, inDialog(find.text('RM 14.00 received')));
    await tapIn(tester, inDialog(find.widgetWithText(TextButton, 'Mark paid')));

    expect(find.byType(AlertDialog), findsNothing);
    final debt = await s.db.debt(splitDebt).getSingle();
    expect(debt.status, DebtStatus.paid);
    expect(find.text('Kedai Contoh'), findsNothing);
    await seek(tester, find.text('+ RM 16.00'), up: true);
    expect(find.text('+ RM 16.00'), findsOneWidget);
  });

  testWidgets(
    'a pick in Mark paid during another action keeps the dialog open and says Try again once',
    (tester) async {
      final s = await testServices();
      final ali = await seedAli(s);
      final cashDebt = await debtIdOf(s, manual: true);
      await openPage(tester, s, ali);
      await tapIn(
        tester,
        find.descendant(
          of: find.byKey(ValueKey(cashDebt)),
          matching: find.widgetWithText(TextButton, 'Mark paid'),
        ),
      );
      final vm = vmOf(tester);

      // An open transaction queues every other query: the first action stays busy.
      final release = Completer<void>();
      unawaited(s.db.transaction(() => release.future));
      vm.markItemPaid(vm.detail!.iOwe.single.id, 'Marked paid');
      await tester.tap(inDialog(find.text('Paid in cash')));
      await tester.tap(inDialog(find.widgetWithText(TextButton, 'Mark paid')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Try again in a moment.'), findsOneWidget);
      expect(inDialog(find.text('Mark RM 20.00 paid')), findsOneWidget);
      release.complete();
      await settle(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect((await s.db.debt(cashDebt).getSingle()).status, DebtStatus.open);

      await tapIn(
        tester,
        inDialog(find.widgetWithText(TextButton, 'Mark paid')),
      );
      expect(find.byType(AlertDialog), findsNothing);
      expect((await s.db.debt(cashDebt).getSingle()).status, DebtStatus.paid);
    },
  );

  // Review Focus 1
  testWidgets('an imported QR shows and a replace shows the new picture', (
    tester,
  ) async {
    final files = Directory.systemTemp.createTempSync('koban_files');
    addTearDown(() => files.deleteSync(recursive: true));
    final picked = File(p.join(files.path, 'picked.png'))
      ..writeAsBytesSync(wideBytes);
    final s = await testServices(
      filesDir: files,
      pickImage: () async => picked.path,
    );
    final ali = await seedAli(s);
    // The 0.1.1 import keeps the path of the old app: <files>/qr/<id>.img.
    final qr = File(p.join(files.path, 'qr', '$ali.img'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(pngBytes);
    await s.db.customStatement(
      'UPDATE split_people SET qrPath = ? WHERE id = ?',
      [qr.path, ali],
    );
    await openPage(tester, s, ali);

    expect(find.byType(Image), findsNothing);
    expect(find.text('Save QR to gallery'), findsNothing);
    await tapIn(tester, find.text("Ali's payment QR"));
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      "Ali's payment QR",
    );
    final image = find.byType(Image);
    expect(image, findsOneWidget);
    expect(tester.widget<Image>(image).key, const ValueKey(0));
    final provider = tester.widget<Image>(image).image as ResizeImage;
    expect((provider.imageProvider as FileImage).file.path, qr.path);
    expect((provider.width, provider.height), (1024, 1024));
    expect(find.text('Save QR to gallery'), findsOneWidget);
    expect(
      find.text('Then open your bank app and pick it from the gallery'),
      findsOneWidget,
    );

    // A tap on the QR in the sheet replaces it.
    await tapIn(tester, find.byType(Image));
    final vm = vmOf(tester);
    await settleReal(tester, () => vm.qrVersion == 1);

    expect(tester.widget<Image>(find.byType(Image)).key, const ValueKey(1));
    expect(qr.readAsBytesSync(), wideBytes);
    expect(
      tester.widget<Image>(find.byType(Image)).semanticLabel,
      "Ali's payment QR",
    );
  });

  testWidgets('Delete person closes the page at once and shows Undo', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.people.settleUp(ali);
    final opener = await openPage(tester, s, ali);

    await tapIn(tester, find.byTooltip('Edit Ali'));
    expect(find.text('Edit Ali'), findsOneWidget);
    await tapIn(tester, find.text('Delete person'));
    await settle(tester);

    expect(find.text('Delete Ali?'), findsNothing);
    expect(find.byType(PersonScreen), findsNothing);
    expect(opener.closed, isTrue);
    expect(find.text('Ali deleted'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);
    expect((await s.db.person(ali).getSingle()).archived, isTrue);
  });

  testWidgets('Settle up tells splits with no shop apart', (tester) async {
    final s = await testServices();
    final ali = await s.people.addPerson('Ali');
    Future<void> bill(int time) => s.splits.saveSplit(
      SplitDraft(
        billId: null,
        merchant: null,
        billTime: time,
        currency: 'MYR',
        printedTotal: null,
        items: [
          DraftItem(
            name: 'Nasi',
            quantity: 1,
            price: d('10.00'),
            sharedBy: {meId, 'a'},
          ),
        ],
        charges: SplitCharges(),
        people: const [
          SplitPeopleData(id: 'a', name: 'Ali', lastUsedAt: 0, archived: false),
        ],
        linkedExpenseId: null,
      ),
    );
    await bill(day);
    await bill(day + 86400000);
    await s.people.addOwedToMe(ali, 'Cash', d('3'), day);
    await openPage(tester, s, ali);

    await tapIn(tester, find.widgetWithText(OutlinedButton, 'Settle up'));
    expect(
      inDialog(
        find.text(
          'Ali pays you RM 13.00. This closes 2 splits: Split, 13 Nov and '
          'Split, 14 Nov; 1 item: Cash, 13 Nov. '
          'You cannot change their items after this.',
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Delete person asks before it drops an unsaved name', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.people.settleUp(ali);
    await openPage(tester, s, ali);

    await tapIn(tester, find.byTooltip('Edit Ali'));
    await tester.enterText(find.widgetWithText(TextField, 'Name'), 'Alia');
    await tapIn(tester, find.text('Delete person'));
    expect(find.text('Discard changes?'), findsOneWidget);
    await tapIn(tester, find.text('Keep editing'));
    expect(find.text('Edit Ali'), findsOneWidget);
    expect((await s.db.person(ali).getSingle()).archived, isFalse);

    await tapIn(tester, find.text('Delete person'));
    await tapIn(tester, find.text('Discard'));
    expect(find.byType(PersonScreen), findsNothing);
    expect((await s.db.person(ali).getSingle()).archived, isTrue);
  });

  testWidgets('Edit sheet renames, and Delete person says why it is off', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    await tapIn(tester, find.byTooltip('Edit Ali'));
    expect(find.text('Edit Ali'), findsOneWidget);
    expect(find.text('Payment QR'), findsOneWidget);
    expect(find.text('Not added yet'), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Delete person'))
          .onPressed,
      isNull,
    );
    expect(
      find.text('Settle up first. Ali owes you RM 30.00.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Name'),
      'Ali Hassan',
    );
    await tapIn(tester, find.text('Save changes'));

    expect(find.text('Save changes'), findsNothing);
    expect((await s.db.person(ali).getSingle()).name, 'Ali Hassan');
    expect(find.text('Ali Hassan owes you'), findsWidgets);
  });

  testWidgets('an even balance has no Settle up button', (tester) async {
    final s = await testServices();
    final ali = await s.people.addPerson('Ali');
    await s.people.addOwedToMe(ali, 'Cash', d('5'), day);
    await s.people.addOwedItem(ali, 'Parking', d('5'), day);
    await openPage(tester, s, ali);

    expect(find.text("You're even"), findsOneWidget);
    expect(find.text('Settle up'), findsNothing);
    expect(find.text('Send reminder'), findsNothing);
  });

  testWidgets('Mark paid on what I owe shows Undo, and Undo puts it back', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali);

    final item = await s.db.select(s.db.owedItems).getSingle();
    await tapIn(
      tester,
      find.descendant(
        of: find.byKey(ValueKey(item.id)),
        matching: find.widgetWithText(TextButton, 'Mark paid'),
      ),
    );
    expect(find.text('Marked paid: Parking'), findsOneWidget);
    expect((await s.db.owedItem(item.id).getSingle()).status, DebtStatus.paid);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    final back = await s.db.owedItem(item.id).getSingle();
    expect((back.status, back.paidAt), (DebtStatus.open, null));
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('a visible Replace QR button picks a new picture', (
    tester,
  ) async {
    final files = Directory.systemTemp.createTempSync('koban_files');
    addTearDown(() => files.deleteSync(recursive: true));
    final picked = File(p.join(files.path, 'picked.png'))
      ..writeAsBytesSync(wideBytes);
    final s = await testServices(
      filesDir: files,
      pickImage: () async => picked.path,
    );
    final ali = await seedAli(s);
    final qr = File(p.join(files.path, 'qr', '$ali.img'))
      ..createSync(recursive: true)
      ..writeAsBytesSync(pngBytes);
    await s.db.customStatement(
      'UPDATE split_people SET qrPath = ? WHERE id = ?',
      [qr.path, ali],
    );
    await openPage(tester, s, ali);

    await tapIn(tester, find.widgetWithText(TextButton, 'Replace QR'));
    await settleReal(tester, () => vmOf(tester).qrVersion == 1);

    expect(qr.readAsBytesSync(), wideBytes);
  });

  testWidgets('a person that cannot load shows the message, not Loading', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.db.customStatement('DROP TABLE owed_items');
    await openPage(tester, s, ali);

    expect(find.text(loadFailedMessage), findsOneWidget);
    expect(find.text('Loading'), findsNothing);
  });

  testWidgets('the new sheet and dialogs fit at text scale 1.3', (
    tester,
  ) async {
    final s = await testServices();
    final ali = await seedAli(s);
    await openPage(tester, s, ali, textScale: 1.3);

    await tapIn(tester, find.byTooltip('Edit Ali'));
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tester.tapAt(const Offset(10, 10));
    await settle(tester);

    await tapIn(tester, find.widgetWithText(OutlinedButton, 'Settle up'));
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await tapIn(tester, inDialog(find.text('Cancel')));

    await tapIn(tester, find.text('Cash'));
    expect(tester.takeException(), isNull);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  });

  testWidgets(
    'the person page meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final s = await testServices();
      final ali = await seedAli(s);
      await s.expenses.addManualExpense(
        amount: d('30.00'),
        merchant: 'Ali',
        postTime: day,
        type: TransactionType.receive,
      );
      await openPage(tester, s, ali, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
