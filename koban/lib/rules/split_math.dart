import 'package:decimal/decimal.dart';

import 'amount_formatter.dart';

/// The id of the owner in a split.
const String meId = 'me';

/// One line of a bill and the people who share it.
class SplitItemInput {
  const SplitItemInput({required this.price, required this.sharedBy});
  final Decimal price;
  final Set<String> sharedBy;
}

/// Charges of a bill. [discount] is positive and subtracts from the total.
/// [rounding] is signed.
class SplitCharges {
  SplitCharges({
    Decimal? serviceCharge,
    Decimal? tax,
    Decimal? discount,
    Decimal? rounding,
  }) : serviceCharge = serviceCharge ?? Decimal.zero,
       tax = tax ?? Decimal.zero,
       discount = discount ?? Decimal.zero,
       rounding = rounding ?? Decimal.zero;

  final Decimal serviceCharge;
  final Decimal tax;
  final Decimal discount;
  final Decimal rounding;
}

abstract final class SplitMath {
  static const int _precision = 10;
  static final Decimal _cent = Decimal.parse('0.01');

  /// Divide to [_precision] decimal places, half away from zero.
  /// The same as Kotlin BigDecimal.divide(x, 10, RoundingMode.HALF_UP).
  static Decimal _divide(Decimal a, Decimal b) {
    final factor = Decimal.fromBigInt(BigInt.from(10).pow(_precision));
    final scaled = (a / b) * factor.toRational();
    return Decimal.fromBigInt(scaled.round()).shift(-_precision);
  }

  static Decimal _netCharges(SplitCharges c) =>
      c.serviceCharge + c.tax - c.discount + c.rounding;

  static Decimal _sum(Iterable<Decimal> values) =>
      values.fold(Decimal.zero, (s, v) => s + v);

  static Decimal computedTotal(
    List<SplitItemInput> items,
    SplitCharges charges,
  ) => AmountFormatter.toMoney(
    _sum(items.map((i) => i.price)) + _netCharges(charges),
  );

  /// The share of each person. The values add up to [computedTotal].
  /// Throws [ArgumentError] when an item has no person.
  static Map<String, Decimal> shares(
    List<SplitItemInput> items,
    SplitCharges charges,
  ) {
    if (unassignedItemIndexes(items).isNotEmpty) {
      throw ArgumentError('Every item needs at least one person');
    }

    final subtotals = <String, Decimal>{meId: Decimal.zero};
    for (final item in items) {
      final part = _divide(item.price, Decimal.fromInt(item.sharedBy.length));
      for (final person in item.sharedBy) {
        subtotals.update(person, (v) => v + part, ifAbsent: () => part);
      }
    }

    final extra = _netCharges(charges);
    final subtotalSum = _sum(subtotals.values);
    final Map<String, Decimal> exact;
    if (subtotalSum.sign > 0) {
      exact = subtotals.map(
        (person, sub) =>
            MapEntry(person, sub + _divide(extra * sub, subtotalSum)),
      );
    } else {
      final people = {for (final i in items) ...i.sharedBy};
      if (people.isEmpty) people.add(meId);
      final each = _divide(extra, Decimal.fromInt(people.length));
      exact = subtotals.map(
        (person, sub) =>
            MapEntry(person, people.contains(person) ? sub + each : sub),
      );
    }

    final result = <String, Decimal>{};
    var othersTotal = Decimal.zero;
    for (final entry in exact.entries) {
      if (entry.key == meId) continue;
      result[entry.key] = AmountFormatter.toMoney(entry.value);
      othersTotal += result[entry.key]!;
    }
    final total = computedTotal(items, charges);
    // Half-up rounding of others can overshoot the total. Take cents back, from the
    // person whose rounding gained most (ties: id sorting last), so meId never goes negative.
    while (total - othersTotal < Decimal.zero) {
      String? loser;
      Decimal? loserGain;
      for (final person in result.keys) {
        if (result[person]!.sign <= 0) continue;
        final gain = result[person]! - exact[person]!;
        if (loser == null ||
            gain > loserGain! ||
            (gain == loserGain && person.compareTo(loser) > 0)) {
          loser = person;
          loserGain = gain;
        }
      }
      if (loser == null) break;
      result[loser] = result[loser]! - _cent;
      othersTotal -= _cent;
    }
    result[meId] = total - othersTotal;
    return result;
  }

  static List<int> unassignedItemIndexes(List<SplitItemInput> items) => [
    for (var i = 0; i < items.length; i++)
      if (items[i].sharedBy.isEmpty) i,
  ];

  static Decimal ownerSpending(Decimal linkedAmount, Decimal othersOwe) {
    final left = linkedAmount - othersOwe;
    return AmountFormatter.toMoney(left < Decimal.zero ? Decimal.zero : left);
  }
}
