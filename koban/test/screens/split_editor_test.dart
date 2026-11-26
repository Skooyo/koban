import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/app/routes.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/receipts/receipt_photos.dart';
import 'package:koban/rules/receipt_rules.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/split/split_editor_screen.dart';
import 'package:koban/screens/split/split_editor_steps.dart';
import 'package:koban/screens/split/split_editor_view_model.dart';
import 'package:koban/screens/split/split_entry.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../support/fake_backend.dart';
import '../support/harness.dart';

Decimal d(String v) => Decimal.parse(v);

const shareText =
    'Kedai Contoh, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00';

/// A page with one button. The button opens the split editor, or the payment sheet when [payment] is set.
class SplitOpener extends StatefulWidget {
  const SplitOpener({super.key, this.billId, this.expenseId, this.payment});

  final String? billId;
  final String? expenseId;
  final String? payment;

  @override
  State<SplitOpener> createState() => SplitOpenerState();
}

class SplitOpenerState extends State<SplitOpener> {
  bool closed = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        onPressed: () async {
          final billId = widget.billId;
          final payment = widget.payment;
          if (payment != null) {
            await openPaymentEdit(context, payment);
          } else if (billId != null) {
            await openSplitEdit(context, billId);
          } else {
            await openSplitNew(context, expenseId: widget.expenseId);
          }
          setState(() => closed = true);
        },
        child: const Text('Open editor'),
      ),
    ),
  );
}

Future<SplitOpenerState> openEditor(
  WidgetTester tester,
  AppServices s, {
  String? billId,
  String? expenseId,
  String? payment,
  double textScale = 1,
}) async {
  await pumpKoban(
    tester,
    s,
    home: SplitOpener(billId: billId, expenseId: expenseId, payment: payment),
    textScale: textScale,
  );
  await tester.tap(find.text('Open editor'));
  await tester.pumpAndSettle();
  return tester.state<SplitOpenerState>(
    find.byType(SplitOpener, skipOffstage: false),
  );
}

SplitEditorViewModel editorOf(WidgetTester tester) => tester
    .state<SplitEditorScreenState>(find.byType(SplitEditorScreen))
    .viewModel;

/// One spend of 24.00 at 11 Nov 20:15, and its id.
Future<String> addPayment(
  AppServices s, {
  String amount = '24.00',
  String merchant = 'Kedai Contoh',
}) async {
  await s.expenses.addManualExpense(
    amount: d(amount),
    merchant: merchant,
    postTime: DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch,
    type: TransactionType.withdraw,
  );
  return (await s.db.select(s.db.expenses).get()).last.id;
}

/// Saves the draft of the brief with the repository, and gives the bill id.
Future<String> saveDraft(AppServices s, {String? linkedExpenseId}) =>
    s.splits.saveSplit(
      SplitDraft(
        billId: null,
        merchant: 'Kedai Contoh',
        billTime: DateTime(2026, 11, 13, 12).millisecondsSinceEpoch,
        currency: 'MYR',
        printedTotal: null,
        items: [
          DraftItem(
            name: 'Nasi lemak',
            quantity: 1,
            price: d('20.00'),
            sharedBy: {meId, 'ali'},
          ),
          DraftItem(
            name: 'Teh ais',
            quantity: 1,
            price: d('4.00'),
            sharedBy: {'ali'},
          ),
        ],
        charges: SplitCharges(),
        people: const [
          SplitPeopleData(
            id: 'ali',
            name: 'Ali',
            lastUsedAt: 0,
            archived: false,
          ),
        ],
        linkedExpenseId: linkedExpenseId,
      ),
    );

Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> typeInto(WidgetTester tester, Finder f, String text) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.enterText(f, text);
  await tester.pump();
}

bool bottomOn(WidgetTester tester, String label) =>
    tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, label))
        .onPressed !=
    null;

/// Scrolls the list of the step until [f] is built and visible, then taps it.
Future<void> tapIt(WidgetTester tester, Finder f) async {
  if (f.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      f,
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  await tester.ensureVisible(f.last);
  await tester.pumpAndSettle();
  await tester.tap(f.last);
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text) =>
    tapIt(tester, find.text(text));

/// Types [keys] on the keypad of the item sheet. 'x' is Times.
Future<void> pad(WidgetTester tester, String keys) async {
  for (final c in keys.split('')) {
    final key = switch (c) {
      'x' => PadKey.times,
      '.' => PadKey.dot,
      _ => PadKey.values.firstWhere((k) => k.label == c),
    };
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f);
    await tester.tap(f);
    await tester.pump();
  }
}

/// Adds [names] on the people step.
Future<void> addPeople(WidgetTester tester, List<String> names) async {
  expect(find.text('Who ate with you?'), findsOneWidget);
  for (final name in names) {
    await typeInto(tester, field('New person'), name);
    await tester.tap(find.text('Add'));
    await tester.pumpAndSettle();
  }
}

/// People first (Ali), then the items of the brief in the quick-add sheet: Nasi lemak
/// 20.00 for Me and Ali, Teh ais 4.00 for Ali. With [assign] false nobody has an item.
Future<void> typeItems(WidgetTester tester, {bool assign = true}) async {
  await addPeople(tester, ['Ali']);
  await tapText(tester, 'Next');
  await tapText(tester, 'Type items');
  await typeInto(tester, field('Item'), 'Nasi lemak');
  await pad(tester, '20');
  if (assign) {
    await tester.tap(sheetChip('Ali'));
  } else {
    await tester.tap(sheetChip('Me'));
  }
  await tester.pumpAndSettle();
  await tapText(tester, 'Add and next');
  await typeInto(tester, field('Item'), 'Teh ais');
  await pad(tester, '4');
  if (assign) {
    await tester.tap(sheetChip('Me'));
    await tester.pumpAndSettle();
  }
  await tapText(tester, 'Done');
  await typeInto(tester, field('Shop'), 'Kedai Contoh');
}

SplitStep stepOf(WidgetTester tester) => editorOf(tester).state.step;

/// A chip of the open quick-add sheet. The items list under it has chips of the same names.
Finder sheetChip(String name) => find.descendant(
  of: find.byType(BottomSheet),
  matching: find.widgetWithText(FilterChip, name),
);

Finder chip(String name, int at) =>
    find.widgetWithText(FilterChip, name).at(at);

// Receipt reading

List<OcrLine> _row(String name, String price, int top) => [
  OcrLine(name, 10, top, 200, top + 20),
  OcrLine(price, 300, top, 360, top + 20),
];

/// The OCR lines of a receipt: Nasi lemak 20.00, Teh ais 4.00, and the total [total].
List<OcrLine> ocrLines(String total) => [
  OcrLine('Kedai Contoh', 100, 10, 260, 30),
  ..._row('Nasi lemak', '20.00', 60),
  ..._row('Teh ais', '4.00', 100),
  ..._row('TOTAL', total, 160),
];

/// The reply of Claude for the same receipt, with the total 24.00. Seven reads are left today.
const claudeReply =
    '{"merchant":"Kedai Contoh","date":null,'
    '"items":[{"name":"Nasi lemak","quantity":1,"price":20.00},'
    '{"name":"Teh ais","quantity":1,"price":4.00}],'
    '"total":24.00,"readsLeftToday":7}';

/// A photo source that waits until the test completes its answer.
class HeldPhotos implements ReceiptPhotos {
  final answer = Completer<String?>();
  int scans = 0;

  @override
  Future<String?> scan() {
    scans++;
    return answer.future;
  }
}

/// A cache folder with a photo `scan.jpg` in it. The test deletes the folder.
String cachePhoto() {
  final cache = Directory.systemTemp.createTempSync('koban_cache');
  addTearDown(() {
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });
  final path = p.join(cache.path, 'scan.jpg');
  File(path).writeAsBytesSync([1, 2, 3]);
  return path;
}

/// Services that read the photo [path] with the phone and, with [token], with Claude.
/// [claude] is the status of the fake server reply.
Future<({AppServices s, FakeBackend backend})> readServices(
  String path, {
  required String total,
  ReceiptPhotos? photos,
  Future<String?> Function()? pickImage,
  bool token = true,
  int claude = 200,
  Completer<List<OcrLine>>? hold,
  http.Client? client,
}) async {
  final backend = FakeBackend()
    ..on(
      'POST',
      '/functions/v1/read-receipt',
      (r) => http.Response(claudeReply, claude),
    );
  final s = await testServices(
    cacheDir: File(path).parent,
    http: client ?? backend.client,
    secrets: token ? {'device_token': 'test-token'} : const {},
    device: FakeChannel(deviceChannelName, {
      'shrinkReceipt': Uint8List.fromList([1, 2, 3]),
    }),
    ocr: FakeReceiptOcr({path: ocrLines(total)}, later: {path: ?hold}),
    photos: photos,
    pickImage: pickImage,
  );
  return (s: s, backend: backend);
}

/// Lets the file reads of the editor end. They run outside the fake clock of the test.
Future<void> settleReads(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }
}

OutlinedButton galleryButton(WidgetTester tester) =>
    tester.widget(find.widgetWithText(OutlinedButton, 'Choose from gallery'));

void main() {
  testWidgets(
    'the start step says the photo goes to the server with online access',
    (tester) async {
      await openEditor(
        tester,
        await testServices(secrets: {'device_token': 'test-token'}),
      );
      await tapText(tester, 'Next');
      expect(
        find.text(
          "Koban reads the items on your phone and with Claude. The photo goes to Koban's server, which deletes it after reading.",
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('people come first, then the start offers the photo and typing', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.text('Who ate with you?'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 1 of 3, People'), findsOneWidget);
    expect(find.text('Tap names. No typing.'), findsNothing);
    expect(find.textContaining('second pass'), findsNothing);
    expect(stepOf(tester), SplitStep.people);
    await tapText(tester, 'Next');
    expect(find.text('Got the receipt?'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 2 of 3, Items'), findsOneWidget);
    expect(
      find.text(
        'Koban reads the items on your phone. The photo is not sent anywhere.',
      ),
      findsOneWidget,
    );
    expect(find.text('Scan receipt'), findsOneWidget);
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tapText(tester, 'Type items');
    // The quick-add sheet opens at once, and adds nothing without a name and a price.
    expect(field('Item'), findsOneWidget);
    expect(bottomOn(tester, 'Add and next'), false);
    await tapText(tester, 'Done');
    expect(stepOf(tester), SplitStep.items);
    expect(find.text('No items yet.'), findsOneWidget);
    expect(bottomOn(tester, 'Next'), false);
  });

  testWidgets(
    'the quick-add sheet multiplies, fills from a recent item and keeps going',
    (tester) async {
      final s = await testServices();
      await saveDraft(s);
      await openEditor(tester, s);
      await addPeople(tester, ['Ali']);
      await tapText(tester, 'Next');
      await tapText(tester, 'Type items');
      await typeInto(tester, field('Item'), 'Teh');
      // The recent item of the saved bill fills the name and the price in one tap.
      await tapText(tester, 'Teh ais · RM 4.00');
      expect(
        tester.widget<TextField>(field('Item')).controller!.text,
        'Teh ais',
      );
      expect(find.text('RM 4.00'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey(PadKey.back)));
      await tester.tap(find.byKey(const ValueKey(PadKey.back)));
      await tester.tap(find.byKey(const ValueKey(PadKey.back)));
      await tester.tap(find.byKey(const ValueKey(PadKey.back)));
      await tester.pump();
      await pad(tester, '3x2.70');
      expect(find.text('3 × 2.70 = RM 8.10'), findsOneWidget);
      await tester.tap(chip('Everyone', 0));
      await tester.pumpAndSettle();
      expect(tester.widget<FilterChip>(chip('Me', 0)).selected, true);
      expect(tester.widget<FilterChip>(chip('Ali', 0)).selected, true);
      expect(find.text('Shared by 2, RM 4.05 each'), findsOneWidget);
      await tapText(tester, 'Add and next');
      expect(find.text('1 added'), findsOneWidget);
      expect(tester.widget<TextField>(field('Item')).controller!.text, '');
      await tapText(tester, 'Done');
      final row = editorOf(tester).state.items.single;
      expect((row.name, row.quantity, row.price), ('Teh ais', '3', '8.10'));
      expect(find.text('Teh ais ×3'), findsOneWidget);
      expect(find.text('RM 8.10'), findsWidgets);
    },
  );

  testWidgets('Scan receipt reads the scanned receipt and shows the items', (
    tester,
  ) async {
    final path = cachePhoto();
    final hold = Completer<List<OcrLine>>();
    final r = await readServices(
      path,
      total: '24.00',
      token: false,
      photos: FakeReceiptPhotos([path]),
      hold: hold,
    );
    await openEditor(tester, r.s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading the receipt…'), findsOneWidget);
    expect(stepOf(tester), SplitStep.reading);
    hold.complete(ocrLines('24.00'));
    await settleReads(tester);
    expect(stepOf(tester), SplitStep.items);
    expect(find.text('Matches the receipt total of RM 24.00.'), findsOneWidget);
    expect(find.text('Nasi lemak'), findsOneWidget);
    expect(r.backend.requests, isEmpty);
  });

  testWidgets('Choose from gallery reads the picked photo', (tester) async {
    final path = cachePhoto();
    final r = await readServices(
      path,
      total: '24.00',
      token: false,
      pickImage: () async => path,
    );
    await openEditor(tester, r.s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Choose from gallery'));
    await settleReads(tester);
    expect(stepOf(tester), SplitStep.items);
    expect(find.text('Teh ais'), findsOneWidget);
  });

  testWidgets('a cancelled scan stays on the start step', (tester) async {
    final photos = FakeReceiptPhotos([null, null]);
    final s = await testServices(photos: photos);
    await openEditor(tester, s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await tester.pumpAndSettle();
    expect(find.text('Got the receipt?'), findsOneWidget);
    // The buttons work again: a second scan opens.
    await tester.tap(find.text('Scan receipt'));
    await tester.pumpAndSettle();
    expect(photos.scans, 2);
    expect(find.text('Got the receipt?'), findsOneWidget);
    expect(find.text('Reading the receipt…'), findsNothing);
  });

  testWidgets('a failed pick says so and the buttons work again', (
    tester,
  ) async {
    var calls = 0;
    final s = await testServices(
      pickImage: () async {
        calls++;
        throw StateError('no gallery');
      },
    );
    await openEditor(tester, s);
    await tapText(tester, 'Next');
    expect(find.text('Could not read this photo.'), findsNothing);
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Could not read this photo.'), findsOneWidget);
    expect(
      find.text('Try another photo, or type the items.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Got the receipt?'), findsOneWidget);
    expect(find.text('Type items'), findsOneWidget);
  });

  testWidgets('two fast taps on Scan receipt open one scanner', (tester) async {
    final held = HeldPhotos();
    final s = await testServices(photos: held);
    await openEditor(tester, s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await tester.tap(find.text('Scan receipt'));
    await tester.pump();
    expect(held.scans, 1);
    expect(galleryButton(tester).onPressed, isNull);
    held.answer.complete(null);
    await tester.pumpAndSettle();
    expect(galleryButton(tester).onPressed, isNotNull);
  });

  testWidgets('a photo that arrives after the editor closed is deleted', (
    tester,
  ) async {
    final path = cachePhoto();
    final held = HeldPhotos();
    final r = await readServices(path, total: '24.00', photos: held);
    await openEditor(tester, r.s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await tester.pump();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Open editor'), findsOneWidget);
    held.answer.complete(path);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    expect(File(path).existsSync(), false);
    expect(r.backend.requests, isEmpty);
  });

  testWidgets('the Claude line shows above the items', (tester) async {
    final path = cachePhoto();
    final r = await readServices(
      path,
      total: '24.00',
      photos: FakeReceiptPhotos([path]),
    );
    await openEditor(tester, r.s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await settleReads(tester);
    const line = '✓ Read by Claude · 7 reads left today';
    expect(find.text(line), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(line)).dy,
      lessThan(tester.getTopLeft(find.text('Shop')).dy),
    );
  });

  testWidgets(
    'a gap of 5 sen or less to the receipt fills the rounding itself',
    (tester) async {
      final path = cachePhoto();
      final r = await readServices(
        path,
        total: '24.03',
        token: false,
        photos: FakeReceiptPhotos([path]),
      );
      await openEditor(tester, r.s);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Scan receipt'));
      await settleReads(tester);
      expect(find.text('Fix'), findsNothing);
      expect(SplitEditorViewModel.totalOf(editorOf(tester).state), d('24.03'));
      await tester.scrollUntilVisible(
        find.text('Set to 0.03 to match RM 24.03'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Set to 0.03 to match RM 24.03'), findsOneWidget);
    },
  );

  testWidgets(
    'the fix sheet offers Read again with Claude and shows the wait',
    (tester) async {
      final path = cachePhoto();
      // The first Claude read fails. The second waits for the test.
      final gate = Completer<void>();
      var calls = 0;
      final client = MockClient((request) async {
        if (++calls == 1) return http.Response('{}', 500);
        await gate.future;
        return http.Response(claudeReply, 200);
      });
      final r = await readServices(
        path,
        total: '24.50',
        photos: FakeReceiptPhotos([path]),
        client: client,
      );
      await openEditor(tester, r.s);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Scan receipt'));
      await settleReads(tester);
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      expect(find.text('Read again with Claude'), findsOneWidget);
      expect(find.text("Sends the photo to Koban's server"), findsOneWidget);
      await tester.tap(find.text('Read again with Claude'));
      await tester.pump();
      expect(
        find.text('Reading with Claude… about 10 seconds'),
        findsOneWidget,
      );
      expect(find.text('Read again with Claude'), findsNothing);
      gate.complete();
      await settleReads(tester);
      // Claude matches the total: no mismatch is left and the sheet closes.
      expect(find.text('Reading with Claude… about 10 seconds'), findsNothing);
      expect(find.text('Fix'), findsNothing);
      expect(
        find.text('✓ Read by Claude · 7 reads left today'),
        findsOneWidget,
      );
      expect(stepOf(tester), SplitStep.items);
    },
  );

  testWidgets(
    'a read that ends while the fix sheet closes keeps the editor open',
    (tester) async {
      final path = cachePhoto();
      final gate = Completer<void>();
      var calls = 0;
      final client = MockClient((request) async {
        if (++calls == 1) return http.Response('{}', 500);
        await gate.future;
        return http.Response(claudeReply, 200);
      });
      final r = await readServices(
        path,
        total: '24.50',
        photos: FakeReceiptPhotos([path]),
        client: client,
      );
      await openEditor(tester, r.s);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Scan receipt'));
      await settleReads(tester);
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Read again with Claude'));
      await tester.pump();
      expect(
        find.text('Reading with Claude… about 10 seconds'),
        findsOneWidget,
      );
      // Tap outside: the sheet starts to close while the read runs.
      await tester.tapAt(const Offset(10, 10));
      await tester.pump(const Duration(milliseconds: 50));
      // The read ends and clears the gap while the sheet leaves.
      gate.complete();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      await settleReads(tester);
      expect(find.byType(SplitEditorScreen), findsOneWidget);
      expect(stepOf(tester), SplitStep.items);
    },
  );

  for (final button in ['Add RM 0.50 as rounding', 'Edit by hand']) {
    testWidgets('the fix sheet button "$button" closes only the sheet', (
      tester,
    ) async {
      final path = cachePhoto();
      final r = await readServices(
        path,
        total: '24.50',
        token: false,
        photos: FakeReceiptPhotos([path]),
      );
      await openEditor(tester, r.s);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Scan receipt'));
      await settleReads(tester);
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(stepOf(tester), SplitStep.items);
      expect(
        find.text('Differs from the receipt total by RM 0.50'),
        findsNothing,
      );
    });
  }

  testWidgets(
    'the fix sheet with Read again with Claude fits at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final path = cachePhoto();
      final r = await readServices(
        path,
        total: '24.50',
        claude: 500,
        photos: FakeReceiptPhotos([path]),
      );
      await openEditor(tester, r.s, textScale: 1.3);
      await tapText(tester, 'Next');
      await tester.tap(find.text('Scan receipt'));
      await settleReads(tester);
      await tapText(tester, 'Fix');
      expect(find.text('Read again with Claude'), findsOneWidget);
      expect(find.text("Sends the photo to Koban's server"), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('Back on the reading step returns to the start step', (
    tester,
  ) async {
    final path = cachePhoto();
    final hold = Completer<List<OcrLine>>();
    final r = await readServices(
      path,
      total: '24.00',
      token: false,
      photos: FakeReceiptPhotos([path]),
      hold: hold,
    );
    await openEditor(tester, r.s);
    await tapText(tester, 'Next');
    await tester.tap(find.text('Scan receipt'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading the receipt…'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    // The late read of the phone shows nothing.
    hold.complete(ocrLines('24.00'));
    await settleReads(tester);
    expect(find.text('Got the receipt?'), findsOneWidget);
    expect(stepOf(tester), SplitStep.start);
  });

  testWidgets('a full split from typed items ends on Check and save', (
    tester,
  ) async {
    final s = await testServices();
    final opener = await openEditor(tester, s);
    await typeItems(tester);
    expect(find.text('Pick who had this item.'), findsNothing);
    await tapText(tester, 'Next');
    expect(find.text('Check and save'), findsOneWidget);
    expect(find.bySemanticsLabel('Step 3 of 3, Save'), findsOneWidget);
    expect(find.text('Which payment was this?'), findsNothing);
    expect(find.text('Paid another way'), findsOneWidget);
    expect(find.text('Ali now owes you.'), findsOneWidget);
    expect(find.text('RM 14.00'), findsOneWidget);
    expect(find.text('RM 10.00'), findsOneWidget);
    expect(find.text('RM 24.00'), findsOneWidget);
    expect(find.text('Edit items'), findsNothing);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    final debt = (await s.db.select(s.db.splitDebts).get()).single;
    expect(debt.amount, d('14.00'));
    expect(debt.status, DebtStatus.open);
  });

  testWidgets('Next on the items step is off while an item has nobody', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    await typeItems(tester, assign: false);
    expect(find.text('Pick who had this item.'), findsNWidgets(2));
    expect(bottomOn(tester, 'Next'), false);
    await tapIt(tester, chip('Me', 0));
    expect(find.text('Pick who had this item.'), findsOneWidget);
    expect(bottomOn(tester, 'Next'), false);
    await tapIt(tester, chip('Ali', 1));
    expect(find.text('Pick who had this item.'), findsNothing);
    expect(bottomOn(tester, 'Next'), true);
  });

  testWidgets('a disabled Next says how many items have no one yet', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    await typeItems(tester, assign: false);
    expect(
      find.text('2 items have no one yet. Pick someone to go on.'),
      findsOneWidget,
    );
    await tapIt(tester, chip('Me', 0));
    expect(
      find.text('1 item has no one yet. Pick someone to go on.'),
      findsOneWidget,
    );
    await tapIt(tester, chip('Me', 1));
    expect(find.textContaining('has no one yet'), findsNothing);
    expect(find.textContaining('have no one yet'), findsNothing);
    expect(bottomOn(tester, 'Next'), true);
  });

  testWidgets('Split evenly gives every item to everyone', (tester) async {
    await openEditor(tester, await testServices());
    await typeItems(tester, assign: false);
    await tapText(tester, 'Split evenly');
    final chips = tester.widgetList<FilterChip>(
      find.widgetWithText(FilterChip, 'Everyone'),
    );
    expect([for (final c in chips) c.selected], [true, true]);
    final ali = editorOf(tester).state.people.single.id;
    expect([for (final r in editorOf(tester).state.items) r.sharedBy], [
      {meId, ali},
      {meId, ali},
    ]);
    expect(bottomOn(tester, 'Next'), true);
  });

  testWidgets('the Everyone chip of an item gives it to all, and again to no one', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    await typeItems(tester, assign: false);
    await tapIt(tester, chip('Everyone', 0));
    expect(editorOf(tester).state.items.first.sharedBy.length, 2);
    expect(editorOf(tester).state.items.last.sharedBy, isEmpty);
    await tapIt(tester, chip('Everyone', 0));
    expect(editorOf(tester).state.items.first.sharedBy, isEmpty);
  });

  testWidgets('two people with the same first name keep their full names', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    await addPeople(tester, ['Ali Hassan', 'Ali Hamid', 'Siti Aminah']);
    final state = editorOf(tester).state;
    expect(chipNameOf(state, 'Ali Hassan'), 'Ali Hassan');
    expect(chipNameOf(state, 'Ali Hamid'), 'Ali Hamid');
    expect(chipNameOf(state, 'Siti Aminah'), 'Siti');
  });

  testWidgets('Send summary sends the share text to the device', (
    tester,
  ) async {
    final device = FakeChannel(deviceChannelName, {});
    final s = await testServices(device: device);
    final billId = await saveDraft(s);
    await openEditor(tester, s, billId: billId);
    expect(stepOf(tester), SplitStep.summary);
    expect(find.text('Edit items'), findsOneWidget);
    await tester.tap(find.text('Send summary'));
    await tester.pumpAndSettle();
    final call = device.calls.singleWhere((c) => c.method == 'shareText');
    expect(call.arguments, {
      'text': shareText,
      'chooserTitle': 'Share summary',
    });
  });

  testWidgets('delete split closes at once, with no dialog', (tester) async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final opener = await openEditor(tester, s, billId: billId);
    await tester.ensureVisible(find.text('Delete split'));
    await tester.tap(find.text('Delete split'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this split?'), findsNothing);
    expect(opener.closed, true);
    expect(await s.db.select(s.db.splitBills).get(), isEmpty);
  });

  // Review Focus 4
  testWidgets(
    'Split this bill saves the payment first and opens the editor with it linked',
    (tester) async {
      final s = await testServices();
      final id = await addPayment(s);
      await openEditor(tester, s, payment: id);
      await tester.enterText(find.byType(TextField).first, '26');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Split this bill'));
      await tester.tap(find.text('Split this bill'));
      await tester.pumpAndSettle();
      expect((await s.expenses.getById(id))!.amount, d('26.00'));
      expect(find.text('Who ate with you?'), findsOneWidget);
      final state = editorOf(tester).state;
      expect(state.selectedExpenseId, id);
      expect(
        state.billTime,
        DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch,
      );
    },
  );

  /// From a payment: people, typed items with every item given, then Next.
  Future<void> typeAndNext(WidgetTester tester) async {
    await typeItems(tester);
    await tapText(tester, 'Next');
  }

  testWidgets('a split from a payment skips the link step both ways', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s);
    await openEditor(tester, s, expenseId: id);
    await typeAndNext(tester);
    expect(find.text('Which payment was this?'), findsNothing);
    expect(find.text('Check and save'), findsOneWidget);
    expect(find.textContaining('Your share absorbs'), findsNothing);
    expect(
      find.text('Shares add up to the payment of RM 24.00.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(stepOf(tester), SplitStep.items);
  });

  testWidgets('the summary of a split from a payment shows the mismatch note', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s, amount: '26.00');
    await openEditor(tester, s, expenseId: id);
    await typeAndNext(tester);
    expect(
      find.text(
        'The payment is RM 26.00, the receipt is RM 24.00. '
        'Your share absorbs the difference.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a split without a payment picks one from the Payment row', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s);
    await openEditor(tester, s);
    await typeAndNext(tester);
    expect(find.text('Which payment was this?'), findsNothing);
    await tester.tap(find.text('Payment'));
    await tester.pumpAndSettle();
    expect(find.text('Which payment was this?'), findsOneWidget);
    expect(find.text('Paid another way'), findsOneWidget);
    await tester.tap(find.text('Kedai Contoh'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Done');
    expect(stepOf(tester), SplitStep.summary);
    expect(find.text('Kedai Contoh · RM 24.00'), findsOneWidget);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect(bill.linkedExpenseId, id);
  });

  testWidgets('Back on the people step asks before it drops the people', (
    tester,
  ) async {
    final s = await testServices();
    final opener = await openEditor(tester, s);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    await tester.pumpWidget(const SizedBox());

    final again = await openEditor(tester, s);
    await addPeople(tester, ['Ali']);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(again.closed, false);
    expect(stepOf(tester), SplitStep.people);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(again.closed, true);
  });

  testWidgets(
    'a payment linked to another split shows the refusal on the summary',
    (tester) async {
      final s = await testServices();
      final id = await addPayment(s);
      final opener = await openEditor(tester, s, expenseId: id);
      await typeAndNext(tester);
      expect(find.text('Check and save'), findsOneWidget);
      await saveDraft(s, linkedExpenseId: id);
      await tester.tap(find.text('Save split'));
      await tester.pumpAndSettle();
      expect(
        find.text('This payment already belongs to another split.'),
        findsOneWidget,
      );
      expect(opener.closed, false);
      expect(bottomOn(tester, 'Save split'), true);
      expect((await s.db.select(s.db.splitBills).get()).length, 1);
    },
  );

  testWidgets(
    'the split editor meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final billId = await saveDraft(s);
      Future<void> check() async {
        expect(tester.takeException(), isNull);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      }

      await openEditor(tester, s, textScale: 1.3);
      await check();
      await tapText(tester, 'Next');
      await check();
      await tapText(tester, 'Type items');
      await check();
      await tapText(tester, 'Done');
      await check();
      Navigator.of(tester.element(find.byType(SplitEditorScreen))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await openEditor(tester, s, billId: billId, textScale: 1.3);
      expect(find.text('Split'), findsOneWidget);
      await check();
      editorOf(tester).editItems();
      await tester.pumpAndSettle();
      await check();
      await tester.pumpWidget(const SizedBox());
      await openEditor(tester, s, textScale: 1.3);
      final vm = editorOf(tester)
        ..addPerson('Ali')
        ..next()
        ..splitWithoutReceipt(d('12.50'), 'Taxi');
      await tester.pumpAndSettle();
      expect(vm.state.step, SplitStep.summary);
      await check();
      await tapText(tester, 'Payment');
      await check();
      handle.dispose();
    },
  );

  // No receipt and custom amounts

  /// Adds [people], then taps the no-receipt button [button], which goes to the summary.
  Future<void> noReceiptToSummary(
    WidgetTester tester,
    String button,
    List<String> people,
  ) async {
    await addPeople(tester, people);
    await tapText(tester, 'Next');
    await tapText(tester, button);
  }

  String fieldText(WidgetTester tester, String label) =>
      tester.widget<TextField>(field(label)).controller!.text;

  testWidgets(
    'a payment split with no receipt goes from the start to the summary',
    (tester) async {
      final s = await testServices();
      final id = await addPayment(s, amount: '18.80', merchant: 'Grab');
      final opener = await openEditor(tester, s, expenseId: id);
      await noReceiptToSummary(tester, 'Split RM 18.80 evenly', ['Ali']);
      expect(stepOf(tester), SplitStep.summary);
      expect(find.text('Ali now owes you.'), findsOneWidget);
      expect(find.text('RM 9.40'), findsNWidgets(2));
      expect(find.text('RM 18.80'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Got the receipt?'), findsOneWidget);
      await tapText(tester, 'Split RM 18.80 evenly');
      await tester.tap(find.text('Save split'));
      await tester.pumpAndSettle();
      expect(opener.closed, true);
      final debt = (await s.db.select(s.db.splitDebts).get()).single;
      expect(debt.amount, d('9.40'));
      final item = (await s.db.select(s.db.splitItems).get()).single;
      expect((item.name, item.price), ('Grab', d('18.80')));
      final bill = (await s.db.select(s.db.splitBills).get()).single;
      expect((bill.merchant, bill.linkedExpenseId), ('Grab', id));
      expect((await s.expenses.getById(id))!.countedAmount, d('9.40'));
    },
  );

  testWidgets('RM 10.00 for 3 people gives Me the odd cent', (tester) async {
    final s = await testServices();
    final id = await addPayment(s, amount: '10.00', merchant: 'Grab');
    await openEditor(tester, s, expenseId: id);
    await noReceiptToSummary(tester, 'Split RM 10.00 evenly', ['Ali', 'Bala']);
    expect(find.text('RM 3.33'), findsNWidgets(2));
    expect(find.text('RM 3.34'), findsOneWidget);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    final debts = await s.db.select(s.db.splitDebts).get();
    expect([for (final x in debts) x.amount], [d('3.33'), d('3.33')]);
  });

  testWidgets('a split with no payment asks for the amount and the name', (
    tester,
  ) async {
    final s = await testServices();
    await openEditor(tester, s);
    await noReceiptToSummary(tester, 'Type the total and split evenly', [
      'Ali',
    ]);
    expect(fieldText(tester, 'Name'), 'Shared cost');
    bool nextOn() =>
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Next'))
            .onPressed !=
        null;
    expect(nextOn(), false);
    await tester.enterText(field('Amount (RM)'), '1.234');
    await tester.pump();
    expect(fieldText(tester, 'Amount (RM)'), '');
    await tester.enterText(field('Amount (RM)'), '0');
    await tester.pump();
    expect(nextOn(), false);
    await tester.enterText(field('Amount (RM)'), '12.5');
    await tester.enterText(field('Name'), 'Taxi');
    await tester.pump();
    expect(nextOn(), true);
    await tester.tap(find.widgetWithText(TextButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Which payment was this?'), findsNothing);
    expect(find.text('RM 6.25'), findsNWidgets(2));
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    expect((await s.db.select(s.db.splitDebts).get()).single.amount, d('6.25'));
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect((bill.merchant, bill.linkedExpenseId), ('Taxi', null));
  });

  testWidgets('custom amounts save only when they add up to the total', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s, amount: '18.80', merchant: 'Grab');
    await openEditor(tester, s, expenseId: id);
    await noReceiptToSummary(tester, 'Split RM 18.80 evenly', ['Ali']);
    await tapText(tester, 'Change amounts');
    expect(fieldText(tester, 'Ali (RM)'), '9.40');
    expect(fieldText(tester, 'Me (RM)'), '9.40');
    expect(find.text('Amounts add up to RM 18.80'), findsOneWidget);
    await typeInto(tester, field('Ali (RM)'), '10');
    expect(find.text('RM 0.60 more than the total'), findsOneWidget);
    expect(bottomOn(tester, 'Save split'), false);
    await typeInto(tester, field('Me (RM)'), '8');
    expect(find.text('RM 0.80 left to share'), findsOneWidget);
    expect(bottomOn(tester, 'Save split'), false);
    await typeInto(tester, field('Me (RM)'), '8.80');
    expect(find.text('Amounts add up to RM 18.80'), findsOneWidget);
    expect(bottomOn(tester, 'Save split'), true);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    expect(
      (await s.db.select(s.db.splitDebts).get()).single.amount,
      d('10.00'),
    );
    expect((await s.expenses.getById(id))!.countedAmount, d('8.80'));
    final billId = (await s.db.select(s.db.splitBills).get()).single.id;
    await tester.pumpWidget(const SizedBox());
    await openEditor(tester, s, billId: billId);
    expect(find.text('RM 10.00'), findsOneWidget);
    expect(find.text('RM 8.80'), findsOneWidget);
    expect(find.text('RM 18.80'), findsOneWidget);
  });

  // Owner decision D3 (milestone 6): RM 0 takes the person out of the split.
  testWidgets('RM 0 in Change amounts takes the person out of the split', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s, amount: '18.80', merchant: 'Grab');
    await openEditor(tester, s, expenseId: id);
    await noReceiptToSummary(tester, 'Split RM 18.80 evenly', ['Ali', 'Bala']);
    await tapText(tester, 'Change amounts');
    await typeInto(tester, field('Ali (RM)'), '0');
    await typeInto(tester, field('Bala (RM)'), '9.40');
    await typeInto(tester, field('Me (RM)'), '9.40');
    expect(find.text('Amounts add up to RM 18.80'), findsOneWidget);
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    final people = {
      for (final p in await s.db.select(s.db.splitPeople).get()) p.name: p.id,
    };
    final debts = await s.db.select(s.db.splitDebts).get();
    expect(
      [for (final x in debts) (x.personId, x.amount)],
      [(people['Bala'], d('9.40'))],
    );
    final shares = await s.db.select(s.db.splitItemShares).get();
    expect(shares.map((x) => x.personId), isNot(contains(people['Ali'])));
    expect((await s.expenses.getById(id))!.countedAmount, d('9.40'));
  });

  testWidgets('Split evenly puts the even split back in the fields', (
    tester,
  ) async {
    final s = await testServices();
    final id = await addPayment(s, amount: '18.80', merchant: 'Grab');
    await openEditor(tester, s, expenseId: id);
    await noReceiptToSummary(tester, 'Split RM 18.80 evenly', ['Ali']);
    await tapText(tester, 'Change amounts');
    await typeInto(tester, field('Ali (RM)'), '10');
    await typeInto(tester, field('Me (RM)'), '8.80');
    await tester.tap(find.text('Split evenly'));
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Ali (RM)'), '9.40');
    expect(fieldText(tester, 'Me (RM)'), '9.40');
    await tester.tap(find.text('Save split'));
    await tester.pumpAndSettle();
    expect((await s.db.select(s.db.splitDebts).get()).single.amount, d('9.40'));
    final item = (await s.db.select(s.db.splitItems).get()).single;
    expect((item.name, item.price), ('Grab', d('18.80')));
  });

  testWidgets('only a one-item split offers Change amounts', (tester) async {
    final s = await testServices();
    await openEditor(tester, s);
    await typeAndNext(tester);
    expect(find.text('Check and save'), findsOneWidget);
    expect(find.text('Change amounts'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    final id = await addPayment(s, amount: '18.80', merchant: 'Grab');
    await openEditor(tester, s, expenseId: id);
    await noReceiptToSummary(tester, 'Split RM 18.80 evenly', ['Ali']);
    expect(find.text('Change amounts'), findsOneWidget);
  });
}
