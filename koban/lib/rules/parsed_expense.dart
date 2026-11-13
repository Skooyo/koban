import 'package:decimal/decimal.dart';

import 'types.dart';

/// An expense that the parser read from a notification text.
class ParsedExpense {
  const ParsedExpense({
    required this.amount,
    required this.currency,
    required this.merchant,
    required this.confidence,
    this.transactionType = TransactionType.withdraw,
    this.directionClear = true,
  });

  final Decimal amount;
  final String currency;
  final String? merchant;
  final ParseConfidence confidence;
  final TransactionType transactionType;

  /// False when the text shows no payment word, or both a debit and a credit word.
  final bool directionClear;

  @override
  bool operator ==(Object other) =>
      other is ParsedExpense &&
      other.amount == amount &&
      other.currency == currency &&
      other.merchant == merchant &&
      other.confidence == confidence &&
      other.transactionType == transactionType &&
      other.directionClear == directionClear;

  @override
  int get hashCode => Object.hash(
      amount, currency, merchant, confidence, transactionType, directionClear);

  @override
  String toString() =>
      'ParsedExpense($amount $currency, $merchant, $confidence, $transactionType, directionClear: $directionClear)';
}
