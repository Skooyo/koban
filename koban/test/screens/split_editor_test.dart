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
import 'package:koban/screens/split/split_editor_view_model.dart';
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
Future<String> addPayment(AppServices s) async {
  await s.expenses.addManualExpense(
    amount: d('24.00'),
    merchant: 'Kedai Contoh',
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

/// Types the items of the brief on the Items step and moves to the assign step with Ali added.
Future<void> typeToAssign(WidgetTester tester) async {
  await tester.tap(find.text('Type items instead'));
  await tester.pumpAndSettle();
  await typeInto(tester, field('Place'), 'Kedai Contoh');
  await typeInto(tester, field('Item'), 'Nasi lemak');
  await typeInto(tester, field('Line price (RM)'), '20.00');
  await tester.ensureVisible(find.text('Add item'));
  await tester.tap(find.text('Add item'));
  await tester.pumpAndSettle();
  await typeInto(tester, field('Item').at(1), 'Teh ais');
  await typeInto(tester, field('Line price (RM)').at(1), '4.00');
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  expect(find.text('Who is sharing?'), findsOneWidget);
  await typeInto(tester, field('New person'), 'Ali');
  await tester.tap(find.text('Add'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next · 2 people'));
  await tester.pumpAndSettle();
}

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
  testWidgets('the receipt step offers the photo buttons and typing', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    expect(find.text('Split a bill'), findsOneWidget);
    expect(find.text('Step 1 of 6 · Receipt'), findsOneWidget);
    expect(find.text('Start with the receipt'), findsOneWidget);
    expect(
      find.text(
        'Koban reads the items for you. The photo is read once and then deleted. It is not kept.',
      ),
      findsOneWidget,
    );
    expect(find.text('Choose from gallery'), findsOneWidget);
    expect(find.text('Next'), findsNothing);
    await tester.tap(find.text('Type items instead'));
    await tester.pumpAndSettle();
    expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
    expect(field('Item'), findsOneWidget);
    expect(find.byTooltip('Remove item'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Check the amounts'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Check the amounts'), findsOneWidget);
    expect(bottomOn(tester, 'Next'), false);
  });

  testWidgets('Take photo reads the scanned receipt and shows the items', (
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
    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading the receipt…'), findsOneWidget);
    expect(find.text('Step 1 of 6 · Receipt'), findsOneWidget);
    hold.complete(ocrLines('24.00'));
    await settleReads(tester);
    expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
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
    await tester.tap(find.text('Choose from gallery'));
    await settleReads(tester);
    expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
    expect(find.text('Teh ais'), findsOneWidget);
  });

  testWidgets('a cancelled scan stays on the receipt step', (tester) async {
    final photos = FakeReceiptPhotos([null, null]);
    final s = await testServices(photos: photos);
    await openEditor(tester, s);
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(find.text('Start with the receipt'), findsOneWidget);
    // The buttons work again: a second scan opens.
    await tester.tap(find.text('Take photo'));
    await tester.pumpAndSettle();
    expect(photos.scans, 2);
    expect(find.text('Start with the receipt'), findsOneWidget);
    expect(find.text('Reading the receipt…'), findsNothing);
  });

  testWidgets('a failed pick shows nothing and the buttons work again', (
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
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text('Start with the receipt'), findsOneWidget);
  });

  testWidgets('two fast taps on Take photo open one scanner', (tester) async {
    final held = HeldPhotos();
    final s = await testServices(photos: held);
    await openEditor(tester, s);
    await tester.tap(find.text('Take photo'));
    await tester.tap(find.text('Take photo'));
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
    await tester.tap(find.text('Take photo'));
    await tester.pump();
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
    await tester.tap(find.text('Take photo'));
    await settleReads(tester);
    const line = '✓ Read by Claude · 7 reads left today';
    expect(find.text(line), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(
      tester.getTopLeft(find.text(line)).dy,
      lessThan(tester.getTopLeft(find.text('Place')).dy),
    );
  });

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
      await tester.tap(find.text('Take photo'));
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
      expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
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
      await tester.tap(find.text('Take photo'));
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
      expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
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
      await tester.tap(find.text('Take photo'));
      await settleReads(tester);
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.text('Step 2 of 6 · Items'), findsOneWidget);
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
      await tester.tap(find.text('Take photo'));
      await settleReads(tester);
      await tester.tap(find.text('Fix'));
      await tester.pumpAndSettle();
      expect(find.text('Read again with Claude'), findsOneWidget);
      expect(find.text("Sends the photo to Koban's server"), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );

  testWidgets('Back on the reading step returns to the receipt step', (
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
    await tester.tap(find.text('Take photo'));
    await tester.pump();
    await tester.pump();
    expect(find.text('Reading the receipt…'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    // The late read of the phone shows nothing.
    hold.complete(ocrLines('24.00'));
    await settleReads(tester);
    expect(find.text('Start with the receipt'), findsOneWidget);
    expect(find.text('Step 2 of 6 · Items'), findsNothing);
  });

  testWidgets('a full split from typed items ends on Split done', (
    tester,
  ) async {
    final s = await testServices();
    final opener = await openEditor(tester, s);
    await typeToAssign(tester);
    expect(find.text('Step 4 of 6 · Who had what'), findsOneWidget);
    await tester.tap(chip('Me', 0));
    await tester.tap(chip('Ali', 0));
    await tester.tap(chip('Ali', 1));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Which payment was this?'), findsOneWidget);
    await tester.tap(find.text('Not paid by card'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Split done'), findsOneWidget);
    expect(find.text('Ali now owes you.'), findsOneWidget);
    expect(find.text('RM 14.00'), findsOneWidget);
    expect(find.text('RM 10.00'), findsOneWidget);
    expect(find.text('RM 24.00'), findsOneWidget);
    expect(find.text('Edit items'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(opener.closed, true);
    final debt = (await s.db.select(s.db.splitDebts).get()).single;
    expect(debt.amount, d('14.00'));
    expect(debt.status, DebtStatus.open);
  });

  testWidgets('Next on the assign step is off while an item has nobody', (
    tester,
  ) async {
    await openEditor(tester, await testServices());
    await typeToAssign(tester);
    expect(
      find.text('Tap names to share each item. A shared item splits evenly.'),
      findsOneWidget,
    );
    expect(find.text('Pick at least one person'), findsNWidgets(2));
    expect(bottomOn(tester, 'Next'), false);
    await tester.tap(chip('Me', 0));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one person'), findsOneWidget);
    expect(bottomOn(tester, 'Next'), false);
    await tester.tap(chip('Ali', 1));
    await tester.pumpAndSettle();
    expect(find.text('Pick at least one person'), findsNothing);
    expect(bottomOn(tester, 'Next'), true);
  });

  testWidgets('Share summary sends the share text to the device', (
    tester,
  ) async {
    final device = FakeChannel(deviceChannelName, {});
    final s = await testServices(device: device);
    final billId = await saveDraft(s);
    await openEditor(tester, s, billId: billId);
    expect(find.text('Step 6 of 6 · Summary'), findsOneWidget);
    expect(find.text('Edit items'), findsOneWidget);
    await tester.tap(find.text('Share summary'));
    await tester.pumpAndSettle();
    final call = device.calls.singleWhere((c) => c.method == 'shareText');
    expect(call.arguments, {
      'text': shareText,
      'chooserTitle': 'Share summary',
    });
  });

  testWidgets('delete split asks first and then closes', (tester) async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final opener = await openEditor(tester, s, billId: billId);
    await tester.ensureVisible(find.text('Delete split'));
    await tester.tap(find.text('Delete split'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this split?'), findsOneWidget);
    expect(
      find.text(
        'The bill and what people owe are removed. Your payment counts in full again.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this split?'), findsNothing);
    expect(opener.closed, false);
    await tester.tap(find.text('Delete split'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Delete split'),
      ),
    );
    await tester.pumpAndSettle();
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
      await tester.tap(find.text('RM 24.00'));
      await tester.pumpAndSettle();
      for (var i = 0; i < 5; i++) {
        await tester.tap(find.bySemanticsLabel('Delete digit'));
        await tester.pump();
      }
      await tester.tap(find.text('2'));
      await tester.tap(find.text('6'));
      await tester.pumpAndSettle();
      expect(find.text('RM 26'), findsOneWidget);
      await tester.ensureVisible(find.text('Split this bill'));
      await tester.tap(find.text('Split this bill'));
      await tester.pumpAndSettle();
      expect((await s.expenses.getById(id))!.amount, d('26.00'));
      expect(find.text('Start with the receipt'), findsOneWidget);
      final state = editorOf(tester).state;
      expect(state.selectedExpenseId, id);
      expect(
        state.billTime,
        DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch,
      );
    },
  );

  testWidgets(
    'a payment linked to another split shows the refusal on the summary',
    (tester) async {
      final s = await testServices();
      final id = await addPayment(s);
      final opener = await openEditor(tester, s, expenseId: id);
      await typeToAssign(tester);
      await tester.tap(chip('Me', 0));
      await tester.tap(chip('Ali', 1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Kedai Contoh'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.text('Split done'), findsOneWidget);
      await saveDraft(s, linkedExpenseId: id);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(
        find.text('This payment already belongs to another split.'),
        findsOneWidget,
      );
      expect(opener.closed, false);
      expect(bottomOn(tester, 'Done'), true);
      expect((await s.db.select(s.db.splitBills).get()).length, 1);
    },
  );

  testWidgets(
    'the split editor meets the tap target guidelines and works at text scale 1.3',
    (tester) async {
      final handle = tester.ensureSemantics();
      final s = await testServices();
      final billId = await saveDraft(s);
      await openEditor(tester, s, textScale: 1.3);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await tester.tap(find.text('Type items instead'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      Navigator.of(tester.element(find.byType(SplitEditorScreen))).pop();
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
      await openEditor(tester, s, billId: billId, textScale: 1.3);
      expect(find.text('Split done'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      editorOf(tester).editItems();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    },
  );
}
