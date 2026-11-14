import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/app/app_services.dart';
import 'package:koban/data/database.dart';
import 'package:koban/rules/dedup_key_generator.dart';
import 'package:koban/rules/types.dart';
import 'package:koban/screens/check/check_payments_view_model.dart';

import '../support/harness.dart';

const maybank = 'com.maybank2u.life';

/// The time of the first card: Friday 13 Nov 2026, 12:00, the clock of [testServices].
final cardTime = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;

/// The device channel. It names the Maybank app `MAE`.
FakeChannel maeDevice() => FakeChannel(deviceChannelName, {
  'appLabels': {maybank: 'MAE'},
});

/// Adds one waiting payment. [order] sets `createdAt`, so the oldest card comes first.
Future<String> addCard(
  AppServices s, {
  required int order,
  required String amount,
  required String? merchant,
  required String rawText,
  TransactionType type = TransactionType.withdraw,
  bool directionUnclear = false,
  CaptureFormat format = CaptureFormat.known,
  String? categoryId,
  int? postTime,
}) async {
  final id = 'card$order';
  final time = postTime ?? cardTime - order * 60000;
  await s.db
      .into(s.db.pendingPayments)
      .insert(
        PendingPaymentsCompanion.insert(
          id: id,
          amount: Decimal.parse(amount),
          currency: 'MYR',
          merchant: Value(merchant),
          transactionType: type,
          sourcePackage: maybank,
          rawNotificationText: rawText,
          notificationPostTime: time,
          notificationKey: Value('key$order'),
          dedupKey: DedupKeyGenerator.generate(
            packageName: maybank,
            amount: Decimal.parse(amount),
            merchant: merchant,
            postTime: time,
          ),
          format: format,
          categoryId: Value(categoryId),
          likelyPromotion: false,
          createdAt: 1000 + order,
          edited: false,
          directionUnclear: Value(directionUnclear),
        ),
      );
  return id;
}

/// The three cards of the tests, oldest first: RM 15.00 RESTORAN CONTOH,
/// RM 8.00 Kedai Contoh, RM 50.00 received from ALI.
/// The shop memory puts Kedai Contoh in Transport.
Future<void> addThreeCards(AppServices s) async {
  await addCard(
    s,
    order: 0,
    amount: '15.00',
    merchant: 'RESTORAN CONTOH',
    rawText:
        'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.',
  );
  await addCard(
    s,
    order: 1,
    amount: '8.00',
    merchant: 'Kedai Contoh',
    rawText: 'Successful payment of RM 8.00 to Kedai Contoh. REF: QR123457.',
  );
  await addCard(
    s,
    order: 2,
    amount: '50.00',
    merchant: 'ALI',
    type: TransactionType.receive,
    rawText: 'ALI has transferred RM 50.00 to you.',
  );
  await s.merchants.saveMapping('Kedai Contoh', 'transport');
}

/// Waits until [test] is true. The long limit only stops a broken test.
Future<void> until(CheckPaymentsViewModel vm, bool Function() test) async {
  if (test()) return;
  final done = Completer<void>();
  void check() {
    if (test() && !done.isCompleted) done.complete();
  }

  vm.addListener(check);
  try {
    await done.future.timeout(const Duration(seconds: 10));
  } finally {
    vm.removeListener(check);
  }
}

/// A long hold, so a slow test run cannot end the Undo window.
const longHold = Duration(minutes: 1);

Future<(AppServices, CheckPaymentsViewModel)> start() async {
  final s = await testServices(device: maeDevice(), checkHold: longHold);
  await addThreeCards(s);
  final vm = CheckPaymentsViewModel(s);
  addTearDown(() async {
    vm.dispose();
    await s.paymentChecks.idle;
  });
  await until(vm, () => vm.cards?.length == 3);
  return (s, vm);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'cards come oldest first with the app name and the remembered category',
    () async {
      final (_, vm) = await start();
      final cards = vm.cards!;
      expect(
        [for (final c in cards) c.payment.merchant],
        ['RESTORAN CONTOH', 'Kedai Contoh', 'ALI'],
      );
      expect([for (final c in cards) c.appName], ['MAE', 'MAE', 'MAE']);
      expect([for (final c in cards) c.categoryId], [null, 'transport', null]);
      expect(
        [for (final c in cards) c.categoryName],
        ['Uncategorized', 'Transport', 'Uncategorized'],
      );
      expect(vm.handled, 0);
      expect(vm.undoLabel, null);
      expect(vm.categories.map((c) => c.id), contains('transport'));
    },
  );

  test('a card category that does not exist shows Uncategorized', () async {
    final s = await testServices(device: maeDevice(), checkHold: longHold);
    await addCard(
      s,
      order: 0,
      amount: '15.00',
      merchant: 'RESTORAN CONTOH',
      rawText: 'x',
      categoryId: 'gone',
    );
    final vm = CheckPaymentsViewModel(s);
    addTearDown(vm.dispose);
    await until(vm, () => vm.cards?.length == 1);
    expect(vm.cards!.single.categoryId, null);
    expect(vm.cards!.single.categoryName, 'Uncategorized');
  });

  test(
    'a swipe hides the card, counts it and shows Saved with the shop',
    () async {
      final (_, vm) = await start();
      vm.swipe('card0', save: true);
      expect(vm.undoLabel, 'Saved RESTORAN CONTOH · Undo');
      expect(vm.handled, 1);
      await until(vm, () => vm.cards!.length == 2);
      expect(vm.cards!.first.payment.id, 'card1');
    },
  );

  test('a swipe of a card with no shop names the amount', () async {
    final s = await testServices(device: maeDevice(), checkHold: longHold);
    await addCard(s, order: 0, amount: '15.00', merchant: null, rawText: 'x');
    final vm = CheckPaymentsViewModel(s);
    addTearDown(() async {
      vm.dispose();
      await s.paymentChecks.idle;
    });
    await until(vm, () => vm.cards?.length == 1);
    vm.swipe('card0', save: false);
    expect(vm.undoLabel, 'Skipped RM 15.00 · Undo');
  });

  test('undo counts back and the pill goes when the card is back', () async {
    final (_, vm) = await start();
    vm.swipe('card0', save: true);
    await until(vm, () => vm.cards!.length == 2);
    vm.undo();
    expect(vm.handled, 0);
    // The pill stays until the card is on the list again.
    expect(vm.undoLabel, 'Saved RESTORAN CONTOH · Undo');
    await until(vm, () => vm.undoLabel == null);
    expect(vm.cards!.map((c) => c.payment.id), ['card0', 'card1', 'card2']);
  });

  test('flushHold commits the swipe at once and hides the pill', () async {
    final (s, vm) = await start();
    vm.swipe('card0', save: true);
    vm.flushHold();
    expect(vm.undoLabel, null);
    await s.paymentChecks.idle;
    final expenses = await s.db.select(s.db.expenses).get();
    expect([for (final e in expenses) e.merchant], ['RESTORAN CONTOH']);
    expect(await s.db.select(s.db.pendingPayments).get(), hasLength(2));
  });

  test('an already saved card gives the already saved message', () async {
    final (s, vm) = await start();
    await s.expenses.saveConfirmed(vm.cards!.first.payment);
    final message = vm.messages.first;
    vm.swipe('card0', save: true);
    vm.flushHold();
    expect(await message, 'Already saved, so it was not added again.');
  });
}
