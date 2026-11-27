import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/receipt_rules.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/split/split_editor_view_model.dart';
import 'package:koban/screens/split/split_entry.dart';
import 'package:path/path.dart' as p;

import '../support/fake_backend.dart';
import '../support/harness.dart';

Decimal d(String v) => Decimal.parse(v);

final billDay = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;
final paidAt = DateTime(2026, 11, 11, 20, 15).millisecondsSinceEpoch;

const ali = SplitPeopleData(
  id: 'ali',
  name: 'Ali',
  lastUsedAt: 0,
  archived: false,
);

/// The draft of the brief: Nasi lemak 20.00 for Me and Ali, Teh ais 4.00 for Ali.
SplitEditorState draft({Decimal? printedTotal, String rounding = ''}) =>
    SplitEditorState(
      billTime: billDay,
      merchant: 'Kedai Contoh',
      printedTotal: printedTotal,
      rounding: rounding,
      items: const [
        ItemRow(
          key: 0,
          name: 'Nasi lemak',
          price: '20.00',
          sharedBy: {meId, 'ali'},
        ),
        ItemRow(key: 1, name: 'Teh ais', price: '4.00', sharedBy: {'ali'}),
      ],
      people: const [ali],
    );

/// One spend of [amount] at 11 Nov 20:15, and its id.
Future<String> addPayment(AppServices s, {String amount = '24.00'}) async {
  await s.expenses.addManualExpense(
    amount: d(amount),
    merchant: 'Kedai Contoh',
    postTime: paidAt,
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
        billTime: billDay,
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
        people: const [ali],
        linkedExpenseId: linkedExpenseId,
      ),
    );

Future<SplitEditorViewModel> open(
  AppServices s, {
  String? billId,
  String? expenseId,
}) async {
  final vm = SplitEditorViewModel(s, billId: billId, expenseId: expenseId);
  addTearDown(vm.dispose);
  await vm.ready;
  return vm;
}

/// Types the draft of the brief into [vm], people first, and moves to the summary.
void typeDraft(SplitEditorViewModel vm) {
  vm.addPerson('Ali');
  vm.next();
  vm.typeItemsInstead();
  vm.setMerchant('Kedai Contoh');
  final aliId = vm.state.people.single.id;
  vm.addItem(
    name: 'Nasi lemak',
    quantity: 1,
    price: d('20.00'),
    sharedBy: {meId, aliId},
  );
  vm.addItem(name: 'Teh ais', quantity: 1, price: d('4.00'), sharedBy: {aliId});
  vm.next();
  vm.next();
}

Future<List<(String, Decimal, DebtStatus)>> debts(AppServices s) async {
  final names = {
    for (final p in await s.db.select(s.db.splitPeople).get()) p.id: p.name,
  };
  return [
    for (final x in await s.db.select(s.db.splitDebts).get())
      (names[x.personId]!, x.amount, x.status),
  ];
}

// Receipt reading

List<OcrLine> _row(String name, String price, int top) => [
  OcrLine(name, 10, top, 200, top + 20),
  OcrLine(price, 300, top, 360, top + 20),
];

/// The OCR lines of an accepted read: Nasi lemak 20.00, Teh ais 4.00, total 24.00.
final ocrLines = [
  OcrLine('Kedai Contoh', 100, 10, 260, 30),
  ..._row('Nasi lemak', '20.00', 60),
  ..._row('Teh ais', '4.00', 100),
  ..._row('TOTAL', '24.00', 160),
];

/// The reply of Claude for the same receipt. Seven reads are left today.
const claudeReply =
    '{"merchant":"Kedai Contoh","date":null,'
    '"items":[{"name":"Nasi lemak","quantity":1,"price":20.00},'
    '{"name":"Teh ais","quantity":1,"price":4.00}],'
    '"total":24.00,"readsLeftToday":7}';

/// A cache folder with a photo in it, and a fake server. The test deletes the folder.
class ReadRig {
  ReadRig(this.s, this.backend, this.cache)
    : path = p.join(cache.path, 'scan.jpg');

  final AppServices s;
  final FakeBackend backend;
  final Directory cache;
  final String path;
}

Future<ReadRig> rig({
  bool token = true,
  List<OcrLine> lines = const [],
  Completer<List<OcrLine>>? late,
  int status = 200,
  String body = claudeReply,
}) async {
  final cache = Directory.systemTemp.createTempSync('koban_cache');
  addTearDown(() {
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  });
  final path = p.join(cache.path, 'scan.jpg');
  File(path).writeAsBytesSync([1, 2, 3]);
  final backend = FakeBackend()
    ..on(
      'POST',
      '/functions/v1/read-receipt',
      (r) => http.Response(body, status),
    );
  final s = await testServices(
    cacheDir: cache,
    http: backend.client,
    secrets: token ? {'device_token': 'test-token'} : const {},
    device: FakeChannel(deviceChannelName, {
      'shrinkReceipt': Uint8List.fromList([1, 2, 3]),
    }),
    ocr: FakeReceiptOcr({path: lines}, later: {path: ?late}),
  );
  return ReadRig(s, backend, cache);
}

/// Waits for the delete of a photo, which runs after the call that asked for it.
Future<void> photoGone(String path) async {
  for (var i = 0; i < 100 && File(path).existsSync(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('a row with no name, a bad quantity or a price of 0 makes the items invalid', () {
    final good = draft();
    expect(SplitEditorViewModel.parseItems(good)!.map((i) => i.price), [
      d('20.00'),
      d('4.00'),
    ]);
    ItemRow first(SplitEditorState s) => s.items.first;
    SplitEditorState withFirst(ItemRow r) =>
        good.copyWith(items: [r, good.items.last]);
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(name: '  ')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(quantity: '0')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(quantity: 'two')),
      ),
      null,
    );
    expect(
      SplitEditorViewModel.parseItems(
        withFirst(first(good).copyWith(price: '0')),
      ),
      null,
    );
  });

  test('the difference is the printed total minus the computed total, null when equal', () {
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('24.50'))),
      d('0.50'),
    );
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('23.00'))),
      d('-1.00'),
    );
    expect(
      SplitEditorViewModel.difference(draft(printedTotal: d('24.00'))),
      null,
    );
    expect(SplitEditorViewModel.difference(draft()), null);
  });

  test('add rounding difference moves the whole gap into rounding', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    await s.db.customStatement(
      "UPDATE split_bills SET printedTotal = '24.50' WHERE id = ?",
      [billId],
    );
    final vm = await open(s, billId: billId);
    vm.editItems();
    vm.addRoundingDifference();
    expect(vm.state.rounding, '0.50');
    expect(SplitEditorViewModel.difference(vm.state), null);
    expect(SplitEditorViewModel.totalOf(vm.state), d('24.50'));
  });

  test('rounding fills a gap of 5 sen to the printed total, and a typed rounding wins', () {
    final auto = draft(printedTotal: d('24.03'));
    expect(SplitEditorViewModel.chargesOf(auto)!.rounding, d('0.03'));
    expect(SplitEditorViewModel.totalOf(auto), d('24.03'));
    expect(SplitEditorViewModel.difference(auto), null);
    final typed = draft(printedTotal: d('24.03'), rounding: '0');
    expect(SplitEditorViewModel.difference(typed), d('0.03'));
    final far = draft(printedTotal: d('24.06'));
    expect(SplitEditorViewModel.difference(far), d('0.06'));
  });

  test(
    'rate charges on a payment save the charges in RM',
    () async {
      final s = await testServices();
      final id = await addPayment(s, amount: '86.40');
      final vm = await open(s, expenseId: id);
      vm.addPerson('Ali');
      vm.next();
      vm.typeItemsInstead();
      final aliId = vm.state.people.single.id;
      vm.addItem(
        name: 'Nasi kandar',
        quantity: 2,
        price: d('25.00'),
        sharedBy: {meId, aliId},
      );
      vm.addItem(
        name: 'Teh tarik',
        quantity: 3,
        price: d('8.10'),
        sharedBy: {aliId},
      );
      vm.setService(const RateCharge(10));
      vm.setTax(const RateCharge(6));
      // 86.40 over 1.16 is a subtotal of 74.48. The items have 33.10 of it.
      expect(SplitEditorViewModel.missingItemsOf(vm.state), d('41.38'));

      vm.addItem(
        name: 'The rest',
        quantity: 1,
        price: d('41.38'),
        sharedBy: {meId, aliId},
      );

      expect(SplitEditorViewModel.missingItemsOf(vm.state), d('0.00'));
      expect(SplitEditorViewModel.totalOf(vm.state), d('86.40'));
      vm.next();
      expect(vm.state.step, SplitStep.summary);
      await vm.done();
      final bill = (await s.db.select(s.db.splitBills).get()).single;
      expect(
        (bill.serviceCharge, bill.tax, bill.rounding),
        (d('7.45'), d('4.47'), d('0.00')),
      );
      expect((await s.expenses.getById(id))!.countedAmount, d('38.50'));
    },
  );

  test('the summary lines list the others first and Me last', () {
    expect(SplitEditorViewModel.summaryLines(draft()), [
      ('Ali', d('14.00')),
      ('Me', d('10.00')),
    ]);
    final unassigned = draft().copyWith(
      items: [
        draft().items.first,
        draft().items.last.copyWith(sharedBy: {}),
      ],
    );
    expect(SplitEditorViewModel.summaryLines(unassigned), null);
  });

  test('the share text has the place, the date, each share and the total', () {
    expect(
      SplitEditorViewModel.shareText(draft()),
      'Kedai Contoh, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00',
    );
    expect(
      SplitEditorViewModel.shareText(draft().copyWith(merchant: ' ')),
      'Bill, 13 Nov 2026\nAli: RM 14.00\nMe: RM 10.00\nTotal: RM 24.00',
    );
  });

  test(
    'a person named Me or a name already in the list is not added',
    () async {
      final vm = await open(await testServices());
      vm.addPerson('Ali');
      vm.addPerson('me');
      vm.addPerson(' ali ');
      vm.addPerson('   ');
      vm.addPerson('Mei');
      expect(vm.state.people.map((p) => p.name), ['Ali', 'Mei']);
    },
  );

  test('removing a person also removes them from every item', () async {
    final vm = await open(await testServices());
    typeDraft(vm);
    final person = vm.state.people.single;
    vm.togglePerson(person);
    expect(vm.state.people, isEmpty);
    expect(vm.state.items.map((i) => i.sharedBy), [
      {meId},
      <String>{},
    ]);
  });

  test(
    'a split from a payment links it and takes its time as the bill time',
    () async {
      final s = await testServices();
      final id = await addPayment(s);
      final vm = await open(s, expenseId: id);
      expect(vm.state.loading, false);
      expect(vm.state.step, SplitStep.people);
      expect(vm.state.selectedExpenseId, id);
      expect(vm.state.billTime, paidAt);
      expect(vm.state.billId, null);
    },
  );

  test(
    'a saved split that fails to load ends the spinner with the error text',
    () async {
      final s = await testServices();
      final id = await saveDraft(s);
      await s.db.customStatement('DROP TABLE split_item_shares');

      final vm = await open(s, billId: id);

      expect(vm.state.loading, false);
      expect(vm.state.error, 'Could not open the split. Try again.');
    },
  );

  test(
    'a payment that already has a split opens that split on the summary',
    () async {
      final s = await testServices();
      final id = await addPayment(s);
      final billId = await saveDraft(s, linkedExpenseId: id);
      final vm = await open(s, expenseId: id);
      expect(vm.state.billId, billId);
      expect(vm.state.step, SplitStep.summary);
      expect(vm.state.locked, false);
      expect(vm.state.merchant, 'Kedai Contoh');
      expect(vm.state.items.map((i) => (i.name, i.quantity, i.price)), [
        ('Nasi lemak', '1', '20.00'),
        ('Teh ais', '1', '4.00'),
      ]);
      expect(vm.state.selectedExpenseId, id);
      expect(SplitEditorViewModel.summaryLines(vm.state), [
        ('Ali', d('14.00')),
        ('Me', d('10.00')),
      ]);
    },
  );

  test(
    'back on a saved bill in edit mode asks first, and on a viewed bill leaves',
    () async {
      final s = await testServices();
      final billId = await saveDraft(s);
      final vm = await open(s, billId: billId);
      expect(vm.back(), false);
      vm.editItems();
      expect(vm.state.step, SplitStep.items);
      expect(vm.back(), true);
      expect(vm.state.confirmDiscard, true);
      expect(vm.state.step, SplitStep.items);
      vm.keepEditing();
      expect(vm.state.confirmDiscard, false);
      vm.discardEdits();
      expect(vm.state.confirmDiscard, false);

      final fresh = await open(s);
      fresh.next();
      fresh.typeItemsInstead();
      expect(fresh.back(), true);
      expect(fresh.state.step, SplitStep.start);
      expect(fresh.state.confirmDiscard, false);
      expect(fresh.back(), true);
      expect(fresh.state.step, SplitStep.people);
      expect(fresh.back(), false);
    },
  );

  test('back on the people step asks only when a new split has people', () async {
    final vm = await open(await testServices());
    expect(vm.back(), false);
    vm.addPerson('Ali');
    expect(vm.back(), true);
    expect(vm.state.confirmDiscard, true);
    expect(vm.state.step, SplitStep.people);
    vm.keepEditing();
    expect(vm.state.confirmDiscard, false);
  });

  test('done on a viewed bill saves nothing', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final before = await s.db.select(s.db.splitDebts).get();
    final vm = await open(s, billId: billId);
    await vm.done();
    expect(vm.state.finished, true);
    final after = await s.db.select(s.db.splitDebts).get();
    expect(after.map((x) => x.id), before.map((x) => x.id));
  });

  test('done saves the split and finishes', () async {
    final s = await testServices();
    final vm = await open(s);
    typeDraft(vm);
    expect(vm.state.step, SplitStep.summary);
    await vm.done();
    expect(vm.state.finished, true);
    expect(vm.state.error, null);
    expect(await debts(s), [('Ali', d('14.00'), DebtStatus.open)]);
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect(bill.merchant, 'Kedai Contoh');
    expect(bill.billTime, billDay);
  });

  test('a locked bill only saves its payment link', () async {
    final s = await testServices();
    final billId = await saveDraft(s);
    final debt = (await s.db.select(s.db.splitDebts).get()).single;
    await s.splits.markPaid(debt.id, null);
    final id = await addPayment(s, amount: '24.00');
    final vm = await open(s, billId: billId);
    expect(vm.state.locked, true);
    await vm.done();
    expect(vm.state.finished, false);
    vm.changePayment();
    expect(vm.state.step, SplitStep.link);
    vm.selectExpense(id);
    await vm.saveLockedPayment();
    expect(vm.state.step, SplitStep.summary);
    expect(vm.state.error, null);
    final bill = (await s.db.select(s.db.splitBills).get()).single;
    expect(bill.linkedExpenseId, id);
    expect(await debts(s), [('Ali', d('14.00'), DebtStatus.paid)]);
    final payment = await s.expenses.getById(id);
    expect(payment!.countedAmount, d('10.00'));
  });

  group('reading a receipt', () {
    test('with a token the phone and Claude read together and the Claude read wins', () async {
      final r = await rig(lines: ocrLines);
      final vm = await open(r.s);

      await vm.readReceipt(r.path);

      expect(vm.state.step, SplitStep.items);
      expect(vm.state.items.map((i) => (i.name, i.price)), [
        ('Nasi lemak', '20.00'),
        ('Teh ais', '4.00'),
      ]);
      expect(vm.state.merchant, 'Kedai Contoh');
      expect(vm.state.printedTotal, d('24.00'));
      expect(vm.state.readSource, '✓ Read by Claude · 7 reads left today');
      expect(vm.state.readsLeft, 7);
      expect(vm.state.readNote, 'Matches the receipt total of RM 24.00.');
      expect(vm.state.message, null);
      expect(vm.state.canReadAgain, false);
      expect(r.backend.requests, hasLength(1));
    });

    test(
      'without a token only the phone reads and no request is sent',
      () async {
        final r = await rig(token: false, lines: ocrLines);
        final vm = await open(r.s);

        await vm.readReceipt(r.path);

        expect(vm.state.step, SplitStep.items);
        expect(vm.state.items.map((i) => i.name), ['Nasi lemak', 'Teh ais']);
        expect(vm.state.readNote, 'Matches the receipt total of RM 24.00.');
        expect(vm.state.readSource, null);
        expect(vm.state.canReadAgain, false);
        expect(r.backend.requests, isEmpty);
      },
    );

    test('a cancelled token is removed and the phone read is shown', () async {
      final r = await rig(lines: ocrLines, status: 401, body: '{}');
      final vm = await open(r.s);
      expect(vm.state.onlineAccess, true);

      await vm.readReceipt(r.path);

      expect(r.s.online.secrets.deviceToken.value, '');
      expect(
        vm.state.readSource,
        'Read on the phone. Your invite code is no longer active.',
      );
      expect(vm.state.items.map((i) => i.name), ['Nasi lemak', 'Teh ais']);
      expect(vm.state.onlineAccess, false);
      expect(vm.state.canReadAgain, false);
    });

    test('a photo with nothing readable asks for the items by hand', () async {
      final r = await rig(token: false);
      final vm = await open(r.s);

      await vm.readReceipt(r.path);

      expect(vm.state.step, SplitStep.items);
      expect(vm.state.items, isEmpty);
      expect(
        vm.state.message,
        "Could not read this receipt. Add the items by hand.",
      );
    });

    test('a read with no printed total asks to check the items', () async {
      final r = await rig(
        token: false,
        lines: [
          OcrLine('Kedai Contoh', 100, 10, 260, 30),
          ..._row('Nasi lemak', '20.00', 60),
        ],
      );
      final vm = await open(r.s);

      await vm.readReceipt(r.path);

      expect(vm.state.printedTotal, null);
      expect(
        vm.state.message,
        'No total found on the receipt. Check the items.',
      );
    });

    test('back during reading ignores the late result', () async {
      final wait = Completer<List<OcrLine>>();
      final r = await rig(token: false, late: wait);
      final vm = await open(r.s);

      final reading = vm.readReceipt(r.path);
      expect(vm.state.step, SplitStep.reading);
      expect(vm.back(), true);
      expect(vm.state.step, SplitStep.start);
      wait.complete(ocrLines);
      await reading;

      expect(vm.state.step, SplitStep.start);
      expect(vm.state.items, isEmpty);
      await photoGone(r.path);
      expect(File(r.path).existsSync(), false);
    });

    test(
      'read again is offered only after a phone-only read with online access',
      () async {
        final down = await rig(lines: ocrLines, status: 500, body: '{}');
        final vm = await open(down.s);
        await vm.readReceipt(down.path);
        expect(
          vm.state.readSource,
          'Read on the phone. Claude was not reachable.',
        );
        expect(vm.state.canReadAgain, true);

        down.backend.on(
          'POST',
          '/functions/v1/read-receipt',
          (r) => http.Response(claudeReply, 200),
        );
        await vm.readAgainWithClaude();

        expect(vm.state.readSource, '✓ Read by Claude · 7 reads left today');
        expect(vm.state.items.map((i) => i.name), ['Nasi lemak', 'Teh ais']);
        expect(vm.state.canReadAgain, false);
        expect(vm.state.readingAgain, false);
      },
    );

    test(
      'a Claude read that used a read of the day is not offered again',
      () async {
        final r = await rig(lines: ocrLines, status: 504, body: '{}');
        final vm = await open(r.s);

        await vm.readReceipt(r.path);

        expect(
          vm.state.readSource,
          "Read on the phone. Claude could not read this receipt. This used 1 of today's reads.",
        );
        expect(vm.state.canReadAgain, false);
      },
    );

    test('read again without a token asks for an invite code', () async {
      final r = await rig(lines: ocrLines, status: 500, body: '{}');
      final vm = await open(r.s);
      await vm.readReceipt(r.path);
      await r.s.online.secrets.setDeviceToken('');

      await vm.readAgainWithClaude();

      expect(vm.state.readSource, 'Enter an invite code in Settings first.');
      expect(vm.state.canReadAgain, false);
      expect(r.backend.requests, hasLength(1));
    });

    test('read again follows the device token', () async {
      final r = await rig(lines: ocrLines, status: 500, body: '{}');
      final vm = await open(r.s);
      await vm.readReceipt(r.path);
      expect(vm.state.canReadAgain, true);

      await r.s.online.secrets.setDeviceToken('');
      expect(vm.state.canReadAgain, false);

      await r.s.online.secrets.setDeviceToken('test-token-2');
      expect(vm.state.canReadAgain, true);
    });

    test(
      'a second read again while the first runs sends one request',
      () async {
        final r = await rig(lines: ocrLines, status: 500, body: '{}');
        final vm = await open(r.s);
        await vm.readReceipt(r.path);

        final first = vm.readAgainWithClaude();
        final second = vm.readAgainWithClaude();
        await Future.wait([first, second]);

        expect(r.backend.requests, hasLength(2));
        expect(vm.state.readingAgain, false);
      },
    );

    test('a cancelled token in read again is removed and shown', () async {
      final r = await rig(lines: ocrLines, status: 500, body: '{}');
      final vm = await open(r.s);
      await vm.readReceipt(r.path);
      r.backend.on(
        'POST',
        '/functions/v1/read-receipt',
        (_) => http.Response('{}', 401),
      );

      await vm.readAgainWithClaude();

      expect(r.s.online.secrets.deviceToken.value, '');
      expect(vm.state.readSource, 'Your invite code is no longer active.');
      expect(vm.state.canReadAgain, false);
      expect(vm.state.readingAgain, false);
    });

    test('the photo stays while the items show and goes when the items step closes', () async {
      final r = await rig(token: false, lines: ocrLines);
      final vm = await open(r.s);

      await vm.readReceipt(r.path);
      expect(File(r.path).existsSync(), true);
      vm.next();

      expect(vm.state.step, SplitStep.summary);
      await photoGone(r.path);
      expect(File(r.path).existsSync(), false);
    });

    test('closing the editor deletes the kept photo', () async {
      final r = await rig(token: false, lines: ocrLines);
      final vm = SplitEditorViewModel(r.s);
      await vm.readReceipt(r.path);
      expect(File(r.path).existsSync(), true);

      vm.dispose();

      await photoGone(r.path);
      expect(File(r.path).existsSync(), false);
    });

    test('a photo outside the cache is never deleted', () async {
      final r = await rig(token: false);
      final other = Directory.systemTemp.createTempSync('koban_gallery');
      addTearDown(() => other.deleteSync(recursive: true));
      final outside = p.join(other.path, 'pick.jpg');
      File(outside).writeAsBytesSync([1, 2, 3]);
      final vm = SplitEditorViewModel(r.s);
      await vm.readReceipt(outside);

      vm.next();
      vm.dispose();
      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(File(outside).existsSync(), true);
    });
  });
}
