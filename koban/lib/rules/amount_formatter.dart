import 'package:decimal/decimal.dart';

/// Money rounding and text format. Two decimal places, half up.
abstract final class AmountFormatter {
  static const int _scale = 2;

  /// Round to two decimal places. Half away from zero, the same as Kotlin HALF_UP.
  static Decimal toMoney(Decimal v) => v.round(scale: _scale);

  /// Plain text with always two decimal places, for example "14.50".
  /// Use this text when you store an amount in the database (Room stored
  /// toPlainString of the rounded value, for example 14.50).
  static String formatDisplay(Decimal v) => toMoney(v).toStringAsFixed(_scale);

  /// "1,284.10" for screens. Edit fields keep [formatDisplay] so the text parses back.
  static String formatGrouped(Decimal v) {
    final fixed = formatDisplay(v);
    final negative = fixed.startsWith('-');
    final unsigned = negative ? fixed.substring(1) : fixed;
    final dot = unsigned.indexOf('.');
    final whole = unsigned.substring(0, dot);
    final grouped = whole.replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+$)'),
      (_) => ',',
    );
    return '${negative ? '-' : ''}$grouped${unsigned.substring(dot)}';
  }

  /// "RM" for ringgit, otherwise the currency code.
  static String currencySymbol(String currency) =>
      currency == 'MYR' ? 'RM' : currency;

  /// Read a typed amount. Remove commas, then round to money. Return null if invalid.
  static Decimal? parseInput(String raw) {
    final cleaned = raw.replaceAll(',', '').trim();
    if (cleaned.isEmpty) return null;
    final value = Decimal.tryParse(cleaned);
    return value == null ? null : toMoney(value);
  }
}
