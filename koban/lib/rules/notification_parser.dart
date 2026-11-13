import 'dart:convert';

import 'package:decimal/decimal.dart';

import 'amount_formatter.dart';
import 'merchant_normalizer.dart';
import 'parsed_expense.dart';
import 'types.dart';

/// Read an amount, a direction and a shop name from a bank or wallet notification text.
abstract final class NotificationParser {
  static final RegExp _rmPattern = RegExp(
    r'RM\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _genericPattern = RegExp(
    r'(?:MYR|RM)\s*([\d,]+(?:\.\d{1,2})?)',
    caseSensitive: false,
  );
  static final RegExp _debitKeywords = RegExp(
    r'\b(spent|paid|debited|payment|purchase|charged|withdrawn|withdrawal|transferred)\b',
    caseSensitive: false,
  );
  static final RegExp _creditKeywords = RegExp(
    r'\b(received|credited|refund|refunded|incoming|transfer\s+from|money\s+in)\b',
    caseSensitive: false,
  );

  /// Stop before card and account tails that banks add after the shop name.
  static const String _merchantStop =
      r'(?:\s+with\s+your\b|\s+using\s+your\b|\s+via\s+your\b|\s+from\s+your\b|\.|$)';

  static final List<RegExp> _merchantPatterns = [
    RegExp(r'\bto\s+"([^"]+)', caseSensitive: false),
    RegExp(r"\bto\s+'([^']+)'", caseSensitive: false),
    RegExp(r'\btransferred\s+to\s+(.+?)' + _merchantStop, caseSensitive: false),
    RegExp(r'\bpaid\s+to\s+(.+?)' + _merchantStop, caseSensitive: false),
    RegExp(r'\bpayment\s+to\s+(.+?)' + _merchantStop, caseSensitive: false),
    RegExp(r'\bto\s+(.+?)' + _merchantStop, caseSensitive: false),
    RegExp(r'\bat\s+(.+?)' + _merchantStop, caseSensitive: false),
  ];

  static final RegExp _rmAmountText = RegExp(
    r'RM\s*[\d,]+(?:\.\d{1,2})?',
    caseSensitive: false,
  );
  static final RegExp _anyAmountText = RegExp(
    r'(?:MYR|RM)\s*[\d,]+(?:\.\d{1,2})?',
    caseSensitive: false,
  );

  /// Return the expense in the text, or null when the text has no RM or MYR amount.
  static ParsedExpense? parse(String notificationBody) {
    final body = notificationBody.trim();
    if (body.isEmpty) return null;

    final amounts = findAllAmounts(body);
    if (amounts.isEmpty) return null;

    final amount = amounts.first;
    final transactionType = detectTransactionType(body);
    final confidence = _determineConfidence(body, amounts, transactionType);
    final merchant = extractMerchantFromBody(body, amount);

    return ParsedExpense(
      amount: amount,
      currency: 'MYR',
      merchant: merchant,
      confidence: confidence,
      transactionType: transactionType,
      directionClear: isDirectionClear(body),
    );
  }

  static TransactionType detectTransactionType(String text) {
    final credit = _creditKeywords.hasMatch(text);
    final debit = _debitKeywords.hasMatch(text);
    return credit && !debit
        ? TransactionType.receive
        : TransactionType.withdraw;
  }

  /// True when exactly one of a debit word or a credit word shows,
  /// so [detectTransactionType] is not a guess.
  static bool isDirectionClear(String text) =>
      _creditKeywords.hasMatch(text) != _debitKeywords.hasMatch(text);

  static List<Decimal> findAllAmounts(String text) {
    final matches = <Decimal>[];
    final seen = <String>{};

    for (final pattern in [_rmPattern, _genericPattern]) {
      for (final match in pattern.allMatches(text)) {
        final normalized = normalizeAmount(match.group(1)!);
        if (normalized == null) continue;
        if (seen.add(normalized.toStringAsFixed(2))) {
          matches.add(normalized);
        }
      }
    }
    return matches;
  }

  /// Remove commas and round to 2 decimal places. Return null when the text is not a number.
  static Decimal? normalizeAmount(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = Decimal.tryParse(cleaned);
    return value == null ? null : AmountFormatter.toMoney(value);
  }

  static String? extractMerchantFromBody(String body, Decimal amount) {
    final amountStr = amount.toStringAsFixed(2);
    for (final pattern in _merchantPatterns) {
      final match = pattern.firstMatch(body);
      if (match == null) continue;
      final candidate = _stripAmount(match.group(1)!, amountStr);
      final cleaned = MerchantNormalizer.clean(candidate);
      if (cleaned != null) return cleaned;
    }
    return _fallbackMerchantFromBody(body, amountStr);
  }

  static String? _fallbackMerchantFromBody(String body, String amountStr) {
    for (final line in const LineSplitter().convert(body)) {
      final cleaned = MerchantNormalizer.clean(_stripAmount(line, amountStr));
      if (cleaned != null) return cleaned;
    }
    return null;
  }

  static String _stripAmount(String text, String amountStr) => _trimChars(
    text
        .replaceAll(_rmAmountText, '')
        .replaceAll(_anyAmountText, '')
        .replaceAll(amountStr, '')
        .trim(),
    '-:·•"\'',
  );

  /// Remove the given characters from both ends, like Kotlin String.trim(chars).
  static String _trimChars(String s, String chars) {
    var start = 0;
    var end = s.length;
    while (start < end && chars.contains(s[start])) {
      start++;
    }
    while (end > start && chars.contains(s[end - 1])) {
      end--;
    }
    return s.substring(start, end);
  }

  static ParseConfidence _determineConfidence(
    String text,
    List<Decimal> amounts,
    TransactionType transactionType,
  ) {
    final hasMerchantPattern = _merchantPatterns.any((p) => p.hasMatch(text));
    final hasKeyword =
        _debitKeywords.hasMatch(text) || _creditKeywords.hasMatch(text);
    if (amounts.length > 1) return ParseConfidence.low;
    if (hasMerchantPattern && hasKeyword) return ParseConfidence.high;
    if (hasKeyword) return ParseConfidence.high;
    if (transactionType == TransactionType.withdraw &&
        text.contains('-') &&
        _rmPattern.hasMatch(text)) {
      return ParseConfidence.high;
    }
    return ParseConfidence.medium;
  }
}
