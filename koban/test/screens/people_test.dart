import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:koban/app/app_services.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:koban/screens/people/people_screen.dart';
import 'package:koban/theme/koban_theme.dart';
import 'package:koban/theme/mon.dart';
import 'package:koban/screens/person/person_screen.dart';
import 'package:koban/ui/kit.dart';
import 'package:material_ui/material_ui.dart';

import '../support/harness.dart';
import '../data/qr_store_test.dart' show pngBytes;
import 'person_screen_test.dart' show settle, settleReal;
import 'person_view_model_test.dart' show d, day;

Future<void> openPeople(
  WidgetTester tester,
  AppServices s, {
  double textScale = 1,
}) async {
  await pumpKoban(
    tester,
    s,
    home: const Scaffold(body: SafeArea(child: PeopleScreen())),
    textScale: textScale,
  );
  await settle(tester);
}

Future<void> saveBill(AppServices s, String? merchant) => s.splits.saveSplit(
  SplitDraft(
    billId: null,
    merchant: merchant,
    billTime: day,
    currency: 'MYR',
    printedTotal: null,
    items: [
      DraftItem(
        name: 'Nasi lemak',
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

/// Ali owes you 14.00, you owe Mei 4.00, and Abu is all paid with no QR.
Future<void> seedThree(AppServices s) async {
  final ali = await s.people.addPerson('Ali');
  final mei = await s.people.addPerson('Mei');
  await s.people.addPerson('Abu');
  await s.people.addOwedToMe(ali, 'Cash', d('14'), day);
  await s.people.addOwedItem(mei, 'Parking', d('4'), day);
}

Finder inSheet(Finder f) =>
    find.descendant(of: find.byType(BottomSheet), matching: f);

Finder rowOf(String name) => find.widgetWithText(KobanRow, name);

void main() {
  testWidgets('people show in the You owe, Owes you and Everyone else groups', (
    tester,
  ) async {
    final s = await testServices();
    await seedThree(s);
    await openPeople(tester, s);

    expect(find.text('People'), findsOneWidget);
    final headings = tester
        .widgetList<SectionHeading>(find.byType(SectionHeading))
        .map((h) => h.text);
    expect(headings, ['They owe you', 'You owe', 'Everyone else']);
    for (final (name, line) in [
      ('Mei', 'You owe RM 4.00'),
      ('Ali', 'Owes you RM 14.00'),
      ('Abu', 'No QR saved yet'),
    ]) {
      expect(
        find.descendant(of: rowOf(name), matching: find.text(line)),
        findsOneWidget,
      );
    }
    expect(find.text('Past splits'), findsNothing);
  });

  testWidgets('the balance card shows one net figure and no pills', (
    tester,
  ) async {
    final s = await testServices();
    await seedThree(s);
    await openPeople(tester, s);

    expect(find.text('Owed to you, after what you owe'), findsOneWidget);
    expect(find.text('+ RM 10.00'), findsOneWidget);
    expect(find.text('RM 14.00 owed to you, RM 4.00 you owe'), findsOneWidget);
    expect(find.text('1 owes you'), findsNothing);
    expect(find.text('You owe 1'), findsNothing);
  });

  testWidgets('Add person can save a QR with the name', (tester) async {
    final files = Directory.systemTemp.createTempSync('koban_files');
    // Windows may still hold the picture that the sheet was reading.
    addTearDown(() {
      try {
        files.deleteSync(recursive: true);
      } on FileSystemException {
        // ignore
      }
    });
    final picked = File(p.join(files.path, 'picked.png'))
      ..writeAsBytesSync(pngBytes);
    final s = await testServices(
      filesDir: files,
      pickImage: () async => picked.path,
    );
    await openPeople(tester, s);

    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      inSheet(find.widgetWithText(TextField, 'Name')),
      'Mei Ling',
    );
    await tester.pump();
    await tester.tap(inSheet(find.text("Add Mei Ling's payment QR")));
    await settleReal(
      tester,
      () => find.text('Use this picture?').evaluate().isNotEmpty,
    );
    // The picture is checked first and is not saved yet.
    expect(Directory(p.join(files.path, 'qr')).existsSync(), isFalse);
    await tester.tap(find.text("Use as Mei Ling's QR"));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Picture chosen.')), findsOneWidget);
    await tester.tap(inSheet(find.widgetWithText(FilledButton, 'Add person')));
    final qr = Directory(p.join(files.path, 'qr'));
    await settleReal(
      tester,
      () => find.byType(PersonScreen).evaluate().isNotEmpty,
    );
    await settle(tester);

    expect(find.byType(PersonScreen), findsOneWidget);
    final person = (await s.db.allPeople().get()).single;
    expect(person.name, 'Mei Ling');
    expect(person.qrPath, p.join(qr.path, '${person.id}.img'));
    expect(File(person.qrPath!).readAsBytesSync(), pngBytes);
  });

  testWidgets('closing Add person deletes the picked copy in the cache', (
    tester,
  ) async {
    final cache = Directory.systemTemp.createTempSync('koban_cache');
    addTearDown(() {
      try {
        cache.deleteSync(recursive: true);
      } on FileSystemException {
        // Windows may still hold the picture: leave it for the system.
      }
    });
    final picked = File(p.join(cache.path, 'picked.png'))
      ..writeAsBytesSync(pngBytes);
    final s = await testServices(
      cacheDir: cache,
      pickImage: () async => picked.path,
    );
    await openPeople(tester, s);

    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.text('Add their payment QR')));
    await settleReal(
      tester,
      () => find.text('Use this picture?').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('Use as their QR'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Picture chosen.')), findsOneWidget);
    expect(picked.existsSync(), isTrue);

    // Close the sheet without adding the person.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byType(BottomSheet), findsNothing);
    await settleReal(tester, () => !picked.existsSync());

    expect(await s.db.allPeople().get(), isEmpty);
  });

  testWidgets('search ignores case and extra spaces', (tester) async {
    final s = await testServices();
    await seedThree(s);
    await openPeople(tester, s);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search people'),
      ' ALI ',
    );
    await tester.pumpAndSettle();

    expect(find.byType(KobanRow), findsOneWidget);
    expect(rowOf('Ali'), findsOneWidget);
    expect(find.text('They owe you'), findsOneWidget);
    expect(find.text('You owe'), findsNothing);
  });

  testWidgets('a search with no match says so', (tester) async {
    final s = await testServices();
    await seedThree(s);
    await openPeople(tester, s);

    await tester.enterText(
      find.widgetWithText(TextField, 'Search people'),
      'zzz',
    );
    await tester.pumpAndSettle();

    expect(find.text('Nobody matches that search.'), findsOneWidget);
    expect(find.byType(KobanRow), findsNothing);
  });

  testWidgets('with nobody the tab says how to start', (tester) async {
    final s = await testServices();
    await openPeople(tester, s);

    expect(find.text('No people yet.'), findsOneWidget);
    expect(find.text('Add someone, or split a bill to start.'), findsOneWidget);
    expect(find.byType(Mon), findsOneWidget);
    // No people: nothing to search.
    expect(find.widgetWithText(TextField, 'Search people'), findsNothing);
    expect(find.text('Nobody matches that search.'), findsNothing);
  });

  testWidgets('Add person opens the new person', (tester) async {
    final s = await testServices();
    await openPeople(tester, s);

    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
    expect(inSheet(find.text('Add person')), findsNWidgets(2));
    expect(
      inSheet(find.text('Optional. A picture from your gallery.')),
      findsOneWidget,
    );
    await tester.enterText(
      inSheet(find.widgetWithText(TextField, 'Name')),
      'Ali',
    );
    await tester.tap(inSheet(find.widgetWithText(FilledButton, 'Add person')));
    await settle(tester);

    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(PersonScreen), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PersonScreen),
        matching: find.text('Ali'),
      ),
      findsWidgets,
    );
    expect((await s.db.allPeople().get()).map((p) => p.name), ['Ali']);
  });

  testWidgets('a blank name stays in the dialog with its message', (
    tester,
  ) async {
    final s = await testServices();
    await openPeople(tester, s);

    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
    await tester.tap(inSheet(find.widgetWithText(FilledButton, 'Add person')));
    await settle(tester);

    expect(inSheet(find.text('Enter a name.')), findsOneWidget);
    expect(find.byType(PersonScreen), findsNothing);
    await tester.enterText(
      inSheet(find.widgetWithText(TextField, 'Name')),
      'A',
    );
    await tester.pump();
    expect(find.text('Enter a name.'), findsNothing);
  });

  testWidgets('Past splits open the split and Split a bill starts one', (
    tester,
  ) async {
    final s = await testServices();
    await saveBill(s, 'Kedai Contoh');
    await saveBill(s, null);
    await openPeople(tester, s);

    expect(find.text('Past splits'), findsOneWidget);
    final shop = rowOf('Kedai Contoh');
    expect(
      find.descendant(of: shop, matching: find.text('13 Nov')),
      findsOneWidget,
    );
    expect(rowOf('Split'), findsOneWidget);
    await tester.ensureVisible(shop);
    await tester.pumpAndSettle();
    await tester.tap(shop);
    await settle(tester);
    expect(find.text('Split'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Split a bill'));
    await settle(tester);
    expect(find.text('Who ate with you?'), findsOneWidget);
    expect(find.text('People'), findsOneWidget);
    expect(find.text('Check and save'), findsNothing);
  });

  test('jvmHash gives the Java String.hashCode', () {
    expect(jvmHash(''), 0);
    expect(jvmHash('a'), 97);
    expect(jvmHash('hello'), 99162322);
    expect(jvmHash('polygenelubricants'), -2147483648);
    expect(jvmHash('polygenelubricants') % 5, 2);
  });

  testWidgets('a person with the id a has the third avatar color', (
    tester,
  ) async {
    final s = await testServices();
    await s.db.customStatement(
      "INSERT INTO split_people (id, name, lastUsedAt, archived) VALUES ('a', 'Ali', 0, 0)",
    );
    await openPeople(tester, s);

    final avatar = tester.widget<InitialsAvatar>(
      find.descendant(of: rowOf('Ali'), matching: find.byType(InitialsAvatar)),
    );
    expect(avatar.tint, MoneyColors.of(tester.element(rowOf('Ali'))).orange);
  });

  testWidgets('two fast taps on Add add one person', (tester) async {
    final s = await testServices();
    await openPeople(tester, s);
    var writes = 0;
    final sub = s.db
        .tableUpdates(TableUpdateQuery.onTable(s.db.splitPeople))
        .listen((_) => writes++);
    addTearDown(sub.cancel);

    await tester.tap(find.byTooltip('Add person'));
    await tester.pumpAndSettle();
    await tester.enterText(
      inSheet(find.widgetWithText(TextField, 'Name')),
      'Ali',
    );
    final add = inSheet(find.widgetWithText(FilledButton, 'Add person'));
    await tester.tap(add);
    await tester.tap(add, warnIfMissed: false);
    await settle(tester);

    expect(writes, 1);
    expect((await s.db.allPeople().get()).map((p) => p.name), ['Ali']);
    expect(find.byType(PersonScreen), findsOneWidget);
  });

  testWidgets(
    'the People tab meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final s = await testServices();
      await seedThree(s);
      await saveBill(s, 'Kedai Contoh');
      await openPeople(tester, s, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    },
  );
}
