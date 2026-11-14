import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/data/pending_payment_repository.dart';
import 'package:koban/rules/dedup_key_generator.dart';
import 'package:koban/rules/parsed_expense.dart';
import 'package:koban/rules/types.dart';

const maybank = 'com.maybank2u.life';
const tng = 'my.com.tngdigital.ewallet';
const qrText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
const T = 1762000000000;
const P = T - 60000;

ParsedExpense parsed(
  String amount,
  String? merchant, {
  TransactionType type = TransactionType.withdraw,
  bool clear = true,
}) => ParsedExpense(
  amount: Decimal.parse(amount),
  currency: 'MYR',
  merchant: merchant,
  confidence: ParseConfidence.high,
  transactionType: type,
  directionClear: clear,
);

final rm15 = parsed('15.00', 'RESTORAN CONTOH');
final rm15Key = DedupKeyGenerator.generate(
  packageName: maybank,
  amount: Decimal.parse('15.00'),
  merchant: 'RESTORAN CONTOH',
  postTime: P,
);

void main() {
  // The two-connection test opens two databases on one file on purpose.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late KobanDatabase db;
  late PendingPaymentRepository repo;
  var seq = 0;

  setUp(() {
    db = KobanDatabase(NativeDatabase.memory(setup: configureConnection));
    repo = PendingPaymentRepository(db, now: () => T);
  });
  tearDown(() => db.close());

  Future<void> addExpense({
    String amount = '15.00',
    String? merchant = 'RESTORAN CONTOH',
    TransactionType type = TransactionType.withdraw,
    String pkg = maybank,
    int postTime = P,
    String dedupKey = 'other',
    String? notificationKey,
    ExpenseStatus status = ExpenseStatus.autoSaved,
  }) => db
      .into(db.expenses)
      .insert(
        ExpensesCompanion.insert(
          id: 'e${seq++}',
          amount: Decimal.parse(amount),
          currency: 'MYR',
          merchant: Value(merchant),
          rawNotificationText: 'x',
          sourcePackage: pkg,
          notificationPostTime: postTime,
          createdAt: T,
          dedupKey: dedupKey,
          status: status,
          confidence: ParseConfidence.high,
          notificationKey: Value(notificationKey),
          transactionType: type,
          privateToGroups: false,
        ),
      );

  Future<void> addCard(
    String id, {
    String dedupKey = 'c',
    String? key,
    int postTime = P,
    String amount = '99.00',
    String? merchant = 'X',
    int createdAt = T,
  }) => db
      .into(db.pendingPayments)
      .insert(
        PendingPaymentsCompanion.insert(
          id: id,
          amount: Decimal.parse(amount),
          currency: 'MYR',
          merchant: Value(merchant),
          transactionType: TransactionType.withdraw,
          sourcePackage: maybank,
          rawNotificationText: 'x',
          notificationPostTime: postTime,
          notificationKey: Value(key),
          dedupKey: dedupKey,
          format: CaptureFormat.known,
          likelyPromotion: false,
          createdAt: createdAt,
          edited: false,
        ),
      );

  Future<void> addMarker(String dedupKey, int droppedAt, {String? key}) => db
      .into(db.droppedNotifications)
      .insert(
        DroppedNotificationsCompanion.insert(
          dedupKey: dedupKey,
          notificationKey: Value(key),
          droppedAt: droppedAt,
        ),
      );

  Future<String?> capture(
    ParsedExpense p, {
    String pkg = maybank,
    int postTime = P,
    String? key = 'k1',
    PendingPaymentRepository? r,
  }) => (r ?? repo).capture(
    parsed: p,
    format: CaptureFormat.known,
    rawText: qrText,
    sourcePackage: pkg,
    notificationPostTime: postTime,
    notificationKey: key,
  );

  Future<Object?> cards() async => (await db
          .customSelect('SELECT COUNT(*) AS n FROM pending_payments')
          .getSingle())
      .data['n'];

  test('a new payment becomes a waiting card in the Room formats', () async {
    final id = await repo.capture(
      parsed: rm15,
      format: CaptureFormat.known,
      rawText: qrText,
      sourcePackage: maybank,
      notificationPostTime: P,
      notificationKey: 'k1',
    );
    final row = await db
        .customSelect('SELECT * FROM pending_payments')
        .getSingle();
    expect(row.data, {
      'id': id,
      'amount': '15.00',
      'currency': 'MYR',
      'merchant': 'RESTORAN CONTOH',
      'transactionType': 'WITHDRAW',
      'sourcePackage': maybank,
      'rawNotificationText': qrText,
      'notificationPostTime': P,
      'notificationKey': 'k1',
      'dedupKey': rm15Key,
      'format': 'KNOWN',
      'categoryId': null,
      'likelyPromotion': 0,
      'createdAt': T,
      'edited': 0,
      'directionUnclear': 0,
    });
  });

  test(
    'an expense with the same notification key and post time blocks the card',
    () async {
      await addExpense(notificationKey: 'k1', amount: '1.00', merchant: 'Z');
      expect(await capture(rm15), isNull);
      expect(await cards(), 0);
    },
  );

  test(
    'the same notification key with another post time makes a new card',
    () async {
      await addExpense(
        notificationKey: 'k1',
        postTime: P - 600000,
        amount: '1.00',
        merchant: 'Z',
      );
      expect(await capture(rm15), isA<String>());
      expect(await cards(), 1);
    },
  );

  test('a dismissed expense does not block by notification key or amount',
      () async {
    await addExpense(
      notificationKey: 'k1',
      status: ExpenseStatus.dismissed,
    );
    expect(await capture(rm15), isA<String>());
    expect(await cards(), 1);
  });

  test(
    'an expense with the same dedup key blocks only from 30 minutes before the post time',
    () async {
      // The capture is at P. The check starts at P - 1800000.
      await addExpense(
        dedupKey: rm15Key,
        amount: '1.00',
        merchant: 'Z',
        postTime: P - 1740000,
      );
      expect(await capture(rm15), isNull);
      await db.delete(db.expenses).go();
      await addExpense(
        dedupKey: rm15Key,
        amount: '1.00',
        merchant: 'Z',
        postTime: P - 1800001,
      );
      expect(await capture(rm15), isA<String>());
    },
  );

  test('a dismissed expense with the same dedup key still blocks the card',
      () async {
    await addExpense(
      dedupKey: rm15Key,
      amount: '1.00',
      merchant: 'Z',
      status: ExpenseStatus.dismissed,
    );
    expect(await capture(rm15), isNull);
  });

  test(
    'the same amount and direction within 5 minutes blocks a spend from another app',
    () async {
      await addExpense(pkg: tng, merchant: 'OTHER', postTime: P + 300000);
      expect(await capture(rm15), isNull);
      await db.delete(db.expenses).go();
      await addExpense(pkg: tng, merchant: 'OTHER', postTime: P + 300001);
      expect(await capture(rm15), isA<String>());
    },
  );

  test('a receive is blocked only by the same sender', () async {
    await addExpense(
      amount: '50.00',
      merchant: 'ALI',
      type: TransactionType.receive,
    );
    final ali = parsed('50.00', 'ALI', type: TransactionType.receive);
    final mei = parsed('50.00', 'MEI', type: TransactionType.receive);
    expect(await capture(ali), isNull);
    expect(await capture(mei, key: 'k2'), isA<String>());
  });

  test(
    'a waiting card with the same keys or the same amount blocks a second card',
    () async {
      await addCard('c1', dedupKey: rm15Key);
      expect(await capture(rm15), isNull);
      await db.delete(db.pendingPayments).go();
      await addCard('c2', key: 'k1', postTime: P);
      expect(await capture(rm15), isNull);
      await db.delete(db.pendingPayments).go();
      await addCard('c3', amount: '15.00', postTime: P + 300000);
      expect(await capture(rm15), isNull);
      await db.delete(db.pendingPayments).go();
      await addCard('c4', amount: '15.00', postTime: P + 300001);
      expect(await capture(rm15), isA<String>());
    },
  );

  test('a dropped payment does not come back', () async {
    await addMarker(rm15Key, T);
    expect(await capture(rm15), isNull);
    await db.delete(db.droppedNotifications).go();
    await addMarker('other', T, key: 'k1@$P');
    expect(await capture(rm15), isNull);
    expect(await cards(), 0);
  });

  test('drop markers older than 30 days are deleted at capture', () async {
    await addMarker(rm15Key, T - 2592000001);
    await addMarker('keep', T - 2592000000);
    expect(await capture(rm15), isA<String>());
    final left = await db
        .customSelect('SELECT dedupKey FROM dropped_notifications')
        .get();
    expect(left.map((r) => r.data['dedupKey']).toList(), ['keep']);
  });

  test('a text with no clear direction makes a card with directionUnclear 1',
      () async {
    await capture(parsed('15.00', 'RESTORAN CONTOH', clear: false));
    final row = await db
        .customSelect('SELECT directionUnclear FROM pending_payments')
        .getSingle();
    expect(row.data['directionUnclear'], 1);
  });

  test('force capture skips every check and uses a forced key', () async {
    await addExpense(dedupKey: rm15Key, notificationKey: 'k1');
    expect(
      await repo.forceCapture(
        sourcePackage: maybank,
        rawText: qrText,
        notificationPostTime: P,
      ),
      true,
    );
    final row = await db
        .customSelect(
          'SELECT dedupKey, notificationKey, amount, createdAt FROM pending_payments',
        )
        .getSingle();
    expect(row.data['dedupKey'], startsWith('forced:'));
    expect(row.data['notificationKey'], isNull);
    expect(row.data['amount'], '15.00');
    expect(row.data['createdAt'], T);
  });

  test('force capture returns false when the text has no amount', () async {
    expect(
      await repo.forceCapture(
        sourcePackage: maybank,
        rawText: 'Your statement is ready.',
        notificationPostTime: P,
      ),
      false,
    );
    expect(await cards(), 0);
  });

  test('waiting cards come oldest first', () async {
    await addCard('new', dedupKey: 'a', createdAt: T + 2);
    await addCard('old', dedupKey: 'b', createdAt: T);
    await addCard('mid', dedupKey: 'c', createdAt: T + 1);
    final list = await repo.watchWaiting().first;
    expect(list.map((p) => p.id).toList(), ['old', 'mid', 'new']);
    expect(await repo.watchWaitingCount().first, 3);
  });

  test(
    'two connections that capture the same payment at once make one card',
    () async {
      final dir = Directory.systemTemp.createTempSync('koban_capture');
      final file = File('${dir.path}/k.db');
      final a = KobanDatabase(
        NativeDatabase.createInBackground(file, setup: configureConnection),
      );
      final b = KobanDatabase(
        NativeDatabase.createInBackground(file, setup: configureConnection),
      );
      try {
        await a.customSelect('SELECT 1').get();
        await b.customSelect('SELECT 1').get();
        final repoA = PendingPaymentRepository(a, now: () => T);
        final repoB = PendingPaymentRepository(b, now: () => T);
        final ids = await Future.wait([
          capture(rm15, r: repoA),
          capture(rm15, r: repoB),
        ]);
        expect(ids.whereType<String>().length, 1);
        final n = await a
            .customSelect('SELECT COUNT(*) AS n FROM pending_payments')
            .getSingle();
        expect(n.data['n'], 1);
      } finally {
        await a.close();
        await b.close();
        dir.deleteSync(recursive: true);
      }
    },
  );
}
