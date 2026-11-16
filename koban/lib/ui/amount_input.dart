import 'package:decimal/decimal.dart';
import 'package:flutter/services.dart';

import '../rules/amount_formatter.dart';

/// Typing rules for the payment amount.
/// The text is the raw typed string: no "RM", no grouping.
abstract final class AmountInput {
  static const maxWholeDigits = 9;

  /// Keeps only digits and one '.', at most [maxWholeDigits] whole digits and
  /// 2 decimals. A bad edit, a paste too, leaves the old text. A leading '.' gets a '0'.
  static final formatter = TextInputFormatter.withFunction((old, next) {
    final t = next.text;
    if (!RegExp(r'^\d{0,9}(\.\d{0,2})?$').hasMatch(t)) return old;
    if (!t.startsWith('.')) return next;
    return TextEditingValue(
      text: '0$t',
      selection: TextSelection.collapsed(offset: t.length + 1),
    );
  });

  /// The amount of the text, or null for no amount or zero.
  static Decimal? toAmount(String text) {
    final v = AmountFormatter.parseInput(text);
    return v == null || v == Decimal.zero ? null : v;
  }

  static String fromAmount(Decimal amount) =>
      amount == Decimal.zero ? '' : AmountFormatter.formatDisplay(amount);
}
