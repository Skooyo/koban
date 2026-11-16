import 'package:drift/drift.dart';

import '../rules/amount_formatter.dart';
import '../rules/dedup_key_generator.dart';
import '../rules/parsed_expense.dart';
import '../rules/payment_rules.dart';
import '../rules/types.dart';
import 'database.dart';
import 'expense_dedup.dart';
import 'ids.dart';

/// Drop markers older than 30 days are deleted at each capture.
const _dropMarkerTtlMs = 2592000000;

/// The drop key. Some apps use one notification key for every payment,
/// so the key has the post time too.
String? _dropKey(String? notificationKey, int postTime) =>
    notificationKey == null ? null : '$notificationKey@$postTime';

/// The waiting payments ("Check payments"). The background worker writes them.
class PendingPaymentRepository {
  PendingPaymentRepository(this._db, {int Function()? now})
    : _now = now ?? (() => DateTime.now().millisecondsSinceEpoch);

  final KobanDatabase _db;
  final int Function() _now;

  /// Store a waiting payment. Return its id, or null when an expense,
  /// a waiting payment or a dropped payment already covers it.
  /// All checks and the insert run in one transaction, so two connections
  /// cannot both insert the same payment.
  Future<String?> capture({
    required ParsedExpense parsed,
    required CaptureFormat format,
    required String rawText,
    required String sourcePackage,
    required int notificationPostTime,
    required String? notificationKey,
  }) {
    final amount = AmountFormatter.toMoney(parsed.amount);
    final dedupKey = DedupKeyGenerator.generate(
      packageName: sourcePackage,
      amount: amount,
      merchant: parsed.merchant,
      postTime: notificationPostTime,
    );
    final now = _now();

    return _db.transaction(() async {
      // The delete is a write. It takes the database lock first,
      // so the checks below do not race another connection.
      await _db.deleteDroppedBefore(now - _dropMarkerTtlMs);

      final isExpense = await _db.hasExpenseFor(
        amount: amount,
        transactionType: parsed.transactionType,
        merchant: parsed.merchant,
        postTime: notificationPostTime,
        dedupKey: dedupKey,
        notificationKey: notificationKey,
      );
      if (isExpense) return null;
      if (await _db
              .findPendingByKeys(
                dedupKey,
                notificationKey,
                notificationPostTime,
              )
              .getSingleOrNull() !=
          null) {
        return null;
      }
      final sameAmountWaiting = await _db
          .findPendingByAmountInWindow(
            amount,
            parsed.transactionType,
            parsed.transactionType == TransactionType.receive ? 1 : 0,
            parsed.merchant,
            notificationPostTime - amountDedupWindowMs,
            notificationPostTime + amountDedupWindowMs,
          )
          .getSingleOrNull();
      if (sameAmountWaiting != null) return null;
      if (await _db
              .findDropped(
                dedupKey,
                _dropKey(notificationKey, notificationPostTime),
              )
              .getSingleOrNull() !=
          null) {
        return null;
      }
      return _insertCard(
        parsed,
        format,
        rawText,
        sourcePackage,
        notificationPostTime,
        notificationKey,
        dedupKey,
        now,
      );
    });
  }

  /// Make a card for a logged notification when the owner says it is a real payment.
  /// No duplicate check applies, now or on save. Return false when the text has no amount.
  Future<bool> forceCapture({
    required String sourcePackage,
    required String rawText,
    required int notificationPostTime,
  }) async {
    final match = PaymentRules.match(sourcePackage, rawText);
    if (match is! Matched) return false;
    await _db.transaction(
      () => _insertCard(
        match.expense,
        match.format,
        rawText,
        sourcePackage,
        notificationPostTime,
        null,
        '$forcedDedupPrefix${newId()}',
        _now(),
      ),
    );
    return true;
  }

  Future<String> _insertCard(
    ParsedExpense parsed,
    CaptureFormat format,
    String rawText,
    String sourcePackage,
    int notificationPostTime,
    String? notificationKey,
    String dedupKey,
    int now,
  ) async {
    final id = newId();
    await _db
        .into(_db.pendingPayments)
        .insert(
          PendingPaymentsCompanion.insert(
            id: id,
            amount: AmountFormatter.toMoney(parsed.amount),
            currency: parsed.currency,
            merchant: Value(parsed.merchant),
            transactionType: parsed.transactionType,
            sourcePackage: sourcePackage,
            rawNotificationText: rawText,
            notificationPostTime: notificationPostTime,
            notificationKey: Value(notificationKey),
            dedupKey: dedupKey,
            format: format,
            likelyPromotion: false,
            createdAt: now,
            edited: false,
            directionUnclear: Value(!parsed.directionClear),
          ),
        );
    return id;
  }

  /// The waiting payments, oldest first.
  Stream<List<PendingPayment>> watchWaiting() => _db.observePending().watch();

  /// The number of waiting payments.
  Stream<int> watchWaitingCount() => watchWaiting().map((l) => l.length);
}
