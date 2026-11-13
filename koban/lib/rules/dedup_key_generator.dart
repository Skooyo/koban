import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:decimal/decimal.dart';

import 'amount_formatter.dart';

/// Make the key that finds the same payment when two notifications arrive.
/// The key text must stay the same as the Kotlin app makes it.
abstract final class DedupKeyGenerator {
  /// The same payment notification often arrives twice within 30 minutes.
  static const int _dateBucketMs = 30 * 60 * 1000;

  /// Key from app + amount + time bucket. The shop name is not in the key,
  /// because duplicate notifications often parse the name in a different way.
  /// [postTime] is in milliseconds since 1970 (UTC).
  static String generate({
    required String packageName,
    required Decimal amount,
    required String? merchant,
    required int postTime,
  }) {
    final dateBucket = postTime ~/ _dateBucketMs;
    final normalizedAmount = AmountFormatter.formatDisplay(amount);
    final raw = '$packageName|$normalizedAmount|$dateBucket';
    return sha256.convert(utf8.encode(raw)).toString();
  }

  static int dedupLookbackMs() => _dateBucketMs;
}
