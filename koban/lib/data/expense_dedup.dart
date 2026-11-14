import 'package:decimal/decimal.dart';

import '../rules/amount_formatter.dart';
import '../rules/dedup_key_generator.dart';
import '../rules/types.dart';
import 'database.dart';

/// The amount check looks 5 minutes before and after the post time, inclusive.
const amountDedupWindowMs = 300000;

/// A forced card has a key with this prefix, so the duplicate check skips it.
const forcedDedupPrefix = 'forced:';

extension KobanDatabaseDedup on KobanDatabase {
  /// True when an expense already covers this payment: the same notification,
  /// the same dedup key near [postTime], or the same amount and direction in the amount window.
  Future<bool> hasExpenseFor({
    required Decimal amount,
    required TransactionType transactionType,
    required String? merchant,
    required int postTime,
    required String dedupKey,
    required String? notificationKey,
  }) async {
    if (notificationKey != null &&
        await findExpenseByNotificationKey(notificationKey, postTime)
                .getSingleOrNull() !=
            null) {
      return true;
    }
    final lookback = postTime - DedupKeyGenerator.dedupLookbackMs();
    if (await findExpenseByDedupKeySince(dedupKey, lookback)
            .getSingleOrNull() !=
        null) {
      return true;
    }
    return await findExpenseByAmountInWindow(
          AmountFormatter.toMoney(amount),
          transactionType,
          // Two transfers of one amount from different senders are not duplicates.
          transactionType == TransactionType.receive ? 1 : 0,
          merchant,
          postTime - amountDedupWindowMs,
          postTime + amountDedupWindowMs,
        ).getSingleOrNull() !=
        null;
  }
}
