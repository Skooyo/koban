import 'package:decimal/decimal.dart';

import '../rules/amount_formatter.dart';

/// Number-pad rules for the payment amount.
/// The text is the raw typed string: no "RM", no grouping.
abstract final class AmountInput {
  static const maxWholeDigits = 9;

  /// Add one key (one character) to the text. Return the same text if the key is not allowed.
  static String press(String text, String key) {
    if (key == '.') {
      if (text.contains('.')) return text;
      return text.isEmpty ? '0.' : '$text.';
    }
    if (key.length != 1 || key.compareTo('0') < 0 || key.compareTo('9') > 0) {
      return text;
    }
    if (text == '0') return key;
    if (text.contains('.')) {
      return text.substring(text.indexOf('.') + 1).length >= 2
          ? text
          : text + key;
    }
    return text.length >= maxWholeDigits ? text : text + key;
  }

  static String backspace(String text) =>
      text.isEmpty ? text : text.substring(0, text.length - 1);

  /// The amount of the text, or null for no amount or zero.
  static Decimal? toAmount(String text) {
    final v = AmountFormatter.parseInput(text);
    return v == null || v == Decimal.zero ? null : v;
  }

  static String fromAmount(Decimal amount) =>
      amount == Decimal.zero ? '' : AmountFormatter.formatDisplay(amount);
}
