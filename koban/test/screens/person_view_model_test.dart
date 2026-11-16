import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/split_math.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/person/person_view_model.dart';
import 'package:path/path.dart' as p;

import '../data/qr_store_test.dart' show pngBytes;
import '../support/harness.dart';

Decimal d(String v) => Decimal.parse(v);

final day = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;

/// Ali owes a split debt of 14.00 (Kedai Contoh) and a manual debt of 20.00 (Cash).
/// The owner owes Ali 4.00 (Parking). It gives the id of Ali.
Future<String> seedAli(AppServices s) async {
  final ali = await s.people.addPerson('Ali');
  await s.splits.saveSplit(
    SplitDraft(
      billId: null,
      merchant: 'Kedai Contoh',
      billTime: day,
      currency: 'MYR',
      printedTotal: null,
      items: [
        DraftItem(
          name: 'Nasi lemak',
          quantity: 1,
          price: d('20.00'),
          sharedBy: {meId, 'a'},
        ),
        DraftItem(
          name: 'Teh ais',
          quantity: 1,
          price: d('4.00'),
          sharedBy: {'a'},
        ),
      ],
      charges: SplitCharges(),
      people: const [
        SplitPeopleData(id: 'a', name: 'Ali', lastUsedAt: 0, archived: false),
      ],
      linkedExpenseId: null,
    ),
  );
  await s.people.addOwedToMe(ali, 'Cash', d('20'), day);
  await s.people.addOwedItem(ali, 'Parking', d('4'), day);
  return ali;
}

/// Waits until [done] is true. It fails after about 2 seconds.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 400; i++) {
    if (done()) return;
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  fail('The condition did not become true.');
}

/// A view-model for [personId] that has loaded, and the list of its messages.
Future<(PersonViewModel, List<String>)> open(
  AppServices s,
  String personId,
) async {
  final vm = PersonViewModel(s, personId);
  addTearDown(vm.dispose);
  final messages = <String>[];
  vm.messages.listen(messages.add);
  await until(() => vm.detail != null);
  return (vm, messages);
}

Future<void> idle(PersonViewModel vm) => until(() => !vm.busy);

Future<List<DebtStatus>> debtStatuses(AppServices s) async => [
  for (final x in await s.db.select(s.db.splitDebts).get()) x.status,
];

Future<List<DebtStatus>> itemStatuses(AppServices s) async => [
  for (final x in await s.db.select(s.db.owedItems).get()) x.status,
];

Future<SplitPeopleData> personRow(AppServices s, String id) =>
    (s.db.select(s.db.splitPeople)..where((p) => p.id.equals(id))).getSingle();

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Review Focus 3: one action at a time', () {
    test(
      'a second action during the first says Try again in a moment',
      () async {
        final s = await testServices();
        final ali = await seedAli(s);
        await s.people.addOwedItem(ali, 'Teh', d('3'), day);
        final (vm, messages) = await open(s, ali);
        OwedItem item(String what) =>
            vm.detail!.iOwe.firstWhere((i) => i.description == what);
        final parking = item('Parking');
        final teh = item('Teh');

        vm.markItemPaid(parking.id);
        vm.markItemPaid(teh.id);
        await idle(vm);

        expect(messages, ['Try again in a moment.']);
        expect(
          (await s.db.owedItem(parking.id).getSingle()).status,
          DebtStatus.paid,
        );
        expect(
          (await s.db.owedItem(teh.id).getSingle()).status,
          DebtStatus.open,
        );
      },
    );

    test('two taps on Settle up settle one time', () async {
      final s = await testServices();
      final ali = await seedAli(s);
      final (vm, messages) = await open(s, ali);

      vm.settleUp();
      vm.settleUp();
      vm.markItemPaid(vm.detail!.iOwe.single.id);
      await idle(vm);

      expect(messages, ['Try again in a moment.', 'Try again in a moment.']);
      expect(await debtStatuses(s), [DebtStatus.paid, DebtStatus.paid]);
      expect(await itemStatuses(s), [DebtStatus.paid]);
    });

    test(
      'two taps on Mark paid open one payment choice and mark one debt',
      () async {
        final s = await testServices();
        final ali = await seedAli(s);
        final (vm, messages) = await open(s, ali);
        final cash = vm.detail!.owedToMe.firstWhere((v) => v.manual);

        vm.startPaying(cash);
        vm.startPaying(cash);
        await idle(vm);
        expect(messages, ['Try again in a moment.']);
        expect(vm.paying!.debt.debt.id, cash.debt.id);

        vm.markDebtPaid(null);
        vm.markDebtPaid(null);
        vm.startPaying(cash);
        await idle(vm);

        expect(messages, ['Try again in a moment.', 'Try again in a moment.']);
        expect(vm.paying, isNull);
        expect(
          (await s.db.debt(cash.debt.id).getSingle()).status,
          DebtStatus.paid,
        );
        expect(
          await debtStatuses(s),
          unorderedEquals([DebtStatus.paid, DebtStatus.open]),
        );
      },
    );

    test('two taps on Delete delete one time', () async {
      final s = await testServices();
      final ali = await seedAli(s);
      await s.people.settleUp(ali);
      final (vm, messages) = await open(s, ali);

      vm.delete('Ali deleted');
      vm.delete('Ali deleted');
      await idle(vm);
      await until(() => vm.gone);

      expect(messages, ['Try again in a moment.']);
      expect((await personRow(s, ali)).archived, isTrue);
    });
  });

  test('a refused action sends its message', () async {
    final s = await testServices();
    final ali = await seedAli(s);
    final (vm, messages) = await open(s, ali);

    vm.delete('Ali deleted');
    await idle(vm);

    expect(messages, ['Settle up with them first.']);
    expect(vm.gone, isFalse);
    expect((await personRow(s, ali)).archived, isFalse);
  });

  test('mark paid with a matching receive closes the debt', () async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.expenses.addManualExpense(
      amount: d('14.00'),
      merchant: 'Ali',
      postTime: day,
      type: TransactionType.receive,
    );
    final receive = (await s.db.select(s.db.expenses).get()).single;
    final (vm, messages) = await open(s, ali);
    final split = vm.detail!.owedToMe.firstWhere((v) => !v.manual);

    vm.startPaying(split);
    await idle(vm);
    expect(vm.paying!.candidates.map((e) => e.id), [receive.id]);
    vm.markDebtPaid(receive.id);
    await idle(vm);

    final debt = await s.db.debt(split.debt.id).getSingle();
    expect(debt.status, DebtStatus.paid);
    expect(debt.repaymentExpenseId, receive.id);
    expect(vm.paying, isNull);
    expect(messages, isEmpty);
  });

  test('a stale settle suggestion says it no longer matches', () async {
    final s = await testServices();
    final ali = await seedAli(s);
    await s.expenses.addManualExpense(
      amount: d('99.00'),
      merchant: 'Ali',
      postTime: day,
      type: TransactionType.receive,
    );
    final receive = (await s.db.select(s.db.expenses).get()).single;
    await (s.db.update(s.db.splitPeople)..where((p) => p.id.equals(ali))).write(
      SplitPeopleCompanion(suggestedSettleExpenseId: Value(receive.id)),
    );
    final (vm, messages) = await open(s, ali);

    vm.confirmSettle();
    await idle(vm);

    expect(messages, [
      'That payment no longer matches. Check the amounts and settle up by hand.',
    ]);
    expect(await debtStatuses(s), [DebtStatus.open, DebtStatus.open]);
    expect((await personRow(s, ali)).suggestedSettleExpenseId, isNull);
  });

  test('a refused storage permission says how to save the QR', () async {
    final device = FakeChannel(deviceChannelName, {
      'storageAllowed': false,
      'requestStoragePermission': false,
      'saveImageToGallery': 'content://x',
    });
    final s = await testServices(device: device);
    final ali = await seedAli(s);
    await s.db.customStatement(
      "UPDATE split_people SET qrPath = '/x/qr.img' WHERE id = ?",
      [ali],
    );
    final (vm, messages) = await open(s, ali);

    vm.saveQrToGallery();
    await idle(vm);

    expect(messages, ['Allow storage access to save the QR.']);
    expect(device.calls.map((c) => c.method), [
      'storageAllowed',
      'requestStoragePermission',
    ]);
  });

  test('a saved QR says to open the bank app', () async {
    final device = FakeChannel(deviceChannelName, {
      'storageAllowed': true,
      'saveImageToGallery': 'content://x',
    });
    final s = await testServices(device: device);
    final ali = await seedAli(s);
    await s.db.customStatement(
      "UPDATE split_people SET qrPath = '/x/qr.img' WHERE id = ?",
      [ali],
    );
    final (vm, messages) = await open(s, ali);

    vm.saveQrToGallery();
    await idle(vm);

    expect(messages, ['Saved to gallery. Open your bank app and pick it.']);
    expect(device.calls.last.method, 'saveImageToGallery');
    expect(device.calls.last.arguments, {
      'path': '/x/qr.img',
      'displayName': 'koban-Ali-qr.jpg',
    });
  });

  // Ruling R3: only "That file isn't an image." shows; every other gallery failure is general.
  for (final (native, shown) in [
    ("That file isn't an image.", "That file isn't an image."),
    ("Couldn't save to gallery.", 'Could not save the change. Try again.'),
    (null, 'Could not save the change. Try again.'),
    ('', 'Could not save the change. Try again.'),
  ]) {
    test(
      'a failed gallery save with the native text "$native" says "$shown"',
      () async {
        final s = await testServices();
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        const channel = MethodChannel(deviceChannelName);
        messenger.setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'storageAllowed') return true;
          throw PlatformException(code: 'GALLERY', message: native);
        });
        addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
        final ali = await seedAli(s);
        await s.db.customStatement(
          "UPDATE split_people SET qrPath = '/x/qr.img' WHERE id = ?",
          [ali],
        );
        final (vm, messages) = await open(s, ali);

        vm.saveQrToGallery();
        await idle(vm);

        expect(messages, [shown]);
      },
    );
  }

  test('a pick in Mark paid during another action keeps the choice open and says Try again once', () async {
    final s = await testServices();
    final ali = await seedAli(s);
    final (vm, messages) = await open(s, ali);
    final cash = vm.detail!.owedToMe.firstWhere((v) => v.manual);
    vm.startPaying(cash);
    await idle(vm);

    vm.markItemPaid(vm.detail!.iOwe.single.id);
    expect(vm.markDebtPaid(null), isFalse);
    await idle(vm);

    expect(messages, ['Try again in a moment.']);
    expect(vm.paying!.debt.debt.id, cash.debt.id);
    expect((await s.db.debt(cash.debt.id).getSingle()).status, DebtStatus.open);

    expect(vm.markDebtPaid(null), isTrue);
    await idle(vm);
    expect(vm.paying, isNull);
    expect((await s.db.debt(cash.debt.id).getSingle()).status, DebtStatus.paid);
    expect(messages, ['Try again in a moment.']);
  });

  test('a cancelled QR pick changes nothing and says nothing', () async {
    final s = await testServices(pickImage: () async => null);
    final ali = await seedAli(s);
    final (vm, messages) = await open(s, ali);

    vm.pickQr();
    await until(() => !vm.picking);
    await idle(vm);

    expect(vm.qrVersion, 0);
    expect(messages, isEmpty);
    expect((await personRow(s, ali)).qrPath, isNull);
  });

  test('a QR copy that fails after the picture check keeps the old QR and says it went wrong', () async {
    final files = Directory.systemTemp.createTempSync('koban_files');
    addTearDown(() => files.deleteSync(recursive: true));
    final picked = File(p.join(files.path, 'picked.png'))
      ..writeAsBytesSync(pngBytes);
    final s = await testServices(
      filesDir: files,
      pickImage: () async => picked.path,
    );
    final ali = await seedAli(s);
    // A folder in the place of the temp file makes the copy fail.
    Directory(p.join(files.path, 'qr', '$ali.tmp')).createSync(recursive: true);
    final (vm, messages) = await open(s, ali);

    vm.pickQr();
    await until(() => messages.isNotEmpty);

    expect(messages, ['Could not save the change. Try again.']);
    expect(vm.qrVersion, 0);
    expect((await personRow(s, ali)).qrPath, isNull);
    expect(File(p.join(files.path, 'qr', '$ali.img')).existsSync(), isFalse);
  });

  test('a QR pick deletes the picked copy in the cache and keeps a file outside it', () async {
    final cache = Directory.systemTemp.createTempSync('koban_cache');
    final other = Directory.systemTemp.createTempSync('koban_other');
    addTearDown(() {
      cache.deleteSync(recursive: true);
      other.deleteSync(recursive: true);
    });
    final inside = File(p.join(cache.path, 'in.png'))
      ..writeAsBytesSync(pngBytes);
    final outside = File(p.join(other.path, 'out.png'))
      ..writeAsBytesSync(pngBytes);
    var next = inside;
    final s = await testServices(
      cacheDir: cache,
      pickImage: () async => next.path,
    );
    final ali = await seedAli(s);
    final (vm, _) = await open(s, ali);

    vm.pickQr();
    await until(() => vm.qrVersion == 1);
    await idle(vm);
    expect(inside.existsSync(), isFalse);

    next = outside;
    vm.pickQr();
    await until(() => vm.qrVersion == 2);
    await idle(vm);
    expect(outside.existsSync(), isTrue);
  });

  test('a failed QR copy still deletes the picked copy in the cache', () async {
    final files = Directory.systemTemp.createTempSync('koban_files');
    addTearDown(() => files.deleteSync(recursive: true));
    final picked = File(p.join(files.path, 'picked.png'))
      ..writeAsBytesSync(pngBytes);
    final s = await testServices(
      filesDir: files,
      cacheDir: files,
      pickImage: () async => picked.path,
    );
    final ali = await seedAli(s);
    Directory(p.join(files.path, 'qr', '$ali.tmp')).createSync(recursive: true);
    final (vm, messages) = await open(s, ali);

    vm.pickQr();
    await until(() => messages.isNotEmpty);
    await idle(vm);

    expect(picked.existsSync(), isFalse);
  });
}
