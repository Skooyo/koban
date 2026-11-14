import 'dart:io';

import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/category_repository.dart';
import 'package:koban/data/database.dart';
import 'package:koban/data/expense_repository.dart';
import 'package:koban/data/external_writes.dart';
import 'package:koban/data/merchant_category_repository.dart';
import 'package:koban/data/open_database.dart';
import 'package:koban/data/payment_checks.dart';
import 'package:koban/data/pending_payment_repository.dart';
import 'package:koban/data/split_repository.dart';
import 'package:koban/rules/parsed_expense.dart';
import 'package:koban/rules/types.dart';

const maybank = 'com.maybank2u.life';
const qrText =
    'Successful payment of RM 15.00 to RESTORAN CONTOH. REF: QR123456.';
final T = DateTime(2026, 11, 13, 12).millisecondsSinceEpoch;

Future<String?> capture(KobanDatabase db) =>
    PendingPaymentRepository(db, now: () => T).capture(
      parsed: ParsedExpense(
        amount: Decimal.parse('15.00'),
        currency: 'MYR',
        merchant: 'RESTORAN CONTOH',
        confidence: ParseConfidence.high,
        transactionType: TransactionType.withdraw,
        directionClear: true,
      ),
      format: CaptureFormat.known,
      rawText: qrText,
      sourcePackage: maybank,
      notificationPostTime: T - 60000,
      notificationKey: 'k1',
    );

/// Waits up to 2 s until [done] is true.
Future<void> until(bool Function() done) async {
  for (var i = 0; i < 200 && !done(); i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

void main() {
  // The capture engine and the app have their own connection to one file.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory dir;
  late KobanDatabase a;
  late KobanDatabase b;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('koban_external_');
    final file = File('${dir.path}/koban.sqlite');
    a = KobanDatabase(NativeDatabase(file, setup: configureConnection));
    b = KobanDatabase(NativeDatabase(file, setup: configureConnection));
  });
  tearDown(() async {
    await a.close();
    await b.close();
    dir.deleteSync(recursive: true);
  });

  test(
    'a card written by another connection shows without a restart',
    () async {
      final checks = PaymentChecks(
        db: a,
        pending: PendingPaymentRepository(a, now: () => T),
        expenses: ExpenseRepository(
          a,
          categories: CategoryRepository(a),
          merchants: MerchantCategoryRepository(a, now: () => T),
          splits: SplitRepository(a, now: () => T),
          now: () => DateTime.fromMillisecondsSinceEpoch(T),
        ),
        now: () => T,
      );
      final writes = ExternalWrites(a);
      final counts = <int>[];
      final sub = checks.watchVisibleCount().listen(counts.add);
      addTearDown(sub.cancel);
      await until(() => counts.isNotEmpty);
      expect(counts, [0]);
      await writes.checkNow();

      expect(await capture(b), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(counts.last, 0);

      expect(await writes.checkNow(), true);
      await until(() => counts.last == 1);
      expect(counts.last, 1);
    },
  );

  test('no write from another connection gives no change', () async {
    final writes = ExternalWrites(a);
    await writes.checkNow();
    // A write of the same connection is not a write from another connection.
    expect(await capture(a), isNotNull);
    expect(await writes.checkNow(), false);
    expect(await writes.checkNow(), false);
  });
}
