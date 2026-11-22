import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' show immutable;

import '../../rules/amount_formatter.dart';

/// A service charge or SST line of a bill. The bill stores only RM. A rate is worked
/// out from the item subtotal each time the items change.
@immutable
sealed class Charge {
  const Charge();
}

final class NoCharge extends Charge {
  const NoCharge();

  @override
  bool operator ==(Object other) => other is NoCharge;

  @override
  int get hashCode => 0;
}

/// [percent] of the item subtotal, such as 10 for a service charge of 10%.
final class RateCharge extends Charge {
  const RateCharge(this.percent);

  final int percent;

  @override
  bool operator ==(Object other) =>
      other is RateCharge && other.percent == percent;

  @override
  int get hashCode => percent;
}

/// An RM amount that is not a known rate: read from a receipt, or saved that way.
final class FixedCharge extends Charge {
  const FixedCharge(this.amount);

  final Decimal amount;

  @override
  bool operator ==(Object other) =>
      other is FixedCharge && other.amount.compareTo(amount) == 0;

  @override
  int get hashCode => amount.hashCode;
}

const serviceRates = [10];
const sstRates = [6, 8];

/// [percent] of [subtotal], to the sen.
Decimal rateOf(Decimal subtotal, int percent) =>
    AmountFormatter.toMoney((subtotal * Decimal.fromInt(percent)).shift(-2));

/// The RM that [charge] adds to a bill with the item [subtotal].
Decimal chargeAmount(Charge charge, Decimal subtotal) => switch (charge) {
  NoCharge() => Decimal.zero,
  RateCharge(:final percent) => rateOf(subtotal, percent),
  FixedCharge(:final amount) => amount,
};

/// The charge for a stored or read RM [amount]: a rate of [rates] when it gives exactly
/// [amount], so the shares stay the same.
Charge chargeFrom(Decimal amount, Decimal subtotal, List<int> rates) {
  if (amount.sign == 0) return const NoCharge();
  for (final rate in rates) {
    if (rateOf(subtotal, rate).compareTo(amount) == 0) return RateCharge(rate);
  }
  return FixedCharge(amount);
}

final _maxAutoRounding = Decimal.parse('0.05');

/// The rounding that makes the bill match [printed]: the gap when it is 5 sen or less,
/// else zero. A bigger gap is a mistake for the user to fix, not rounding.
Decimal autoRounding(Decimal printed, Decimal totalBeforeRounding) {
  final gap = printed - totalBeforeRounding;
  return gap.abs() <= _maxAutoRounding ? gap : Decimal.zero;
}

/// The item money that [total] still needs on top of [itemsSum]. [ratePercent] is the sum
/// of the rate charges on the subtotal. [fixed] is every RM charge, a discount negative.
/// Negative when the items are more than [total] allows.
Decimal missingItems({
  required Decimal total,
  required Decimal itemsSum,
  required int ratePercent,
  required Decimal fixed,
}) {
  final subtotal =
      ((total - fixed) * Decimal.fromInt(100)) /
      Decimal.fromInt(100 + ratePercent);
  return AmountFormatter.toMoney(
        subtotal.toDecimal(scaleOnInfinitePrecision: 10),
      ) -
      itemsSum;
}

/// [amount] in [parts] equal parts, to the sen. For display only: the split math gives the
/// odd sen to Me.
Decimal eachOf(Decimal amount, int parts) => AmountFormatter.toMoney(
  (amount / Decimal.fromInt(parts)).toDecimal(scaleOnInfinitePrecision: 10),
);

/// The keys of the item keypad.
enum PadKey {
  d0('0'),
  d1('1'),
  d2('2'),
  d3('3'),
  d4('4'),
  d5('5'),
  d6('6'),
  d7('7'),
  d8('8'),
  d9('9'),
  d00('00'),
  dot('.'),
  back('Delete'),
  times('Times');

  const PadKey(this.label);

  final String label;
}

/// What the keypad holds: a quantity and the typed unit price.
/// "3", Times, "2.70" gives quantity 3 and unit 2.70, so the line is RM 8.10.
@immutable
class KeypadEntry {
  const KeypadEntry({this.quantity = 1, this.unit = ''});

  static const maxQuantity = 999;
  static const _maxWholeDigits = 6;

  final int quantity;

  /// The unit price as typed: digits and at most one '.' with 2 decimals.
  final String unit;

  Decimal? get unitPrice {
    final v = AmountFormatter.parseInput(unit);
    return v == null || v.sign <= 0 ? null : v;
  }

  /// Quantity times unit, to the sen. The bill stores this line price.
  Decimal? get linePrice {
    final u = unitPrice;
    return u == null
        ? null
        : AmountFormatter.toMoney(u * Decimal.fromInt(quantity));
  }

  /// "3 × 2.70", or "2.70" for one.
  String get display => quantity > 1 ? '$quantity × $unit' : unit;

  KeypadEntry withQuantity(int q) =>
      KeypadEntry(quantity: q.clamp(1, maxQuantity), unit: unit);

  KeypadEntry press(PadKey key) {
    switch (key) {
      case PadKey.back:
        if (unit.isNotEmpty) {
          return KeypadEntry(
            quantity: quantity,
            unit: unit.substring(0, unit.length - 1),
          );
        }
        // "3 ×" and Delete gives "3" back as typed text.
        return quantity > 1 ? KeypadEntry(unit: '$quantity') : this;
      case PadKey.times:
        final q = int.tryParse(unit);
        if (quantity > 1 || unit.contains('.') || q == null || q < 1) {
          return this;
        }
        return KeypadEntry(quantity: q.clamp(1, maxQuantity));
      case PadKey.dot:
        if (unit.contains('.')) return this;
        return KeypadEntry(
          quantity: quantity,
          unit: unit.isEmpty ? '0.' : '$unit.',
        );
      case PadKey.d00:
        return press(PadKey.d0).press(PadKey.d0);
      default:
        return _digit(key.label);
    }
  }

  KeypadEntry _digit(String d) {
    final dot = unit.indexOf('.');
    if (dot >= 0 && unit.length - dot > 2) return this;
    if (dot < 0 && unit.length >= _maxWholeDigits && unit != '0') return this;
    final next = unit == '0' ? d : '$unit$d';
    return KeypadEntry(quantity: quantity, unit: next);
  }
}
