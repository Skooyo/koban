import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/split_math.dart';

Decimal d(String s) => Decimal.parse(s);

SplitItemInput item(String price, [Set<String> who = const {}]) =>
    SplitItemInput(price: d(price), sharedBy: who);

Decimal sum(Iterable<Decimal> values) =>
    values.fold(Decimal.zero, (s, v) => s + v);

/// Text with two decimal places, so the test also checks the scale.
Map<String, String> text(Map<String, Decimal> shares) =>
    shares.map((k, v) => MapEntry(k, v.toStringAsFixed(2)));

final example = [
  item('12.00', {'me'}),
  item('3.00', {'a'}),
  item('10.00', {'me', 'a', 'b'}),
];
final exampleCharges = SplitCharges(serviceCharge: d('2.50'), tax: d('1.65'));

void main() {
  test('computed total example', () {
    expect(SplitMath.computedTotal(example, exampleCharges), d('29.15'));
  });

  test('shares example', () {
    expect(text(SplitMath.shares(example, exampleCharges)), {
      'me': '17.88',
      'a': '7.38',
      'b': '3.89',
    });
  });

  test('shares leftover cent goes to me', () {
    expect(
      text(
        SplitMath.shares([
          item('10.00', {'me', 'a', 'b'}),
        ], SplitCharges()),
      ),
      {'me': '3.34', 'a': '3.33', 'b': '3.33'},
    );
  });

  test('shares discount and rounding in proportion', () {
    final result = SplitMath.shares([
      item('20.00', {'me'}),
      item('10.00', {'a'}),
    ], SplitCharges(discount: d('3.00'), rounding: d('-0.02')));
    expect(result['a'], d('8.99'));
    expect(result['me'], d('17.99'));
  });

  test('shares zero subtotal splits charges evenly', () {
    final result = SplitMath.shares([
      item('0.00', {'me', 'a'}),
    ], SplitCharges(serviceCharge: d('2.00')));
    expect(result['me'], d('1.00'));
    expect(result['a'], d('1.00'));
  });

  test('shares me never negative', () {
    expect(
      text(
        SplitMath.shares([
          item('0.05', {'a', 'b', 'c'}),
        ], SplitCharges()),
      ),
      {'me': '0.00', 'a': '0.02', 'b': '0.02', 'c': '0.01'},
    );
  });

  test('shares sum equals computed total', () {
    expect(sum(SplitMath.shares(example, exampleCharges).values), d('29.15'));
  });

  test('shares rejects unassigned item', () {
    expect(
      () => SplitMath.shares([
        item('5.00', {'me'}),
        item('4.00'),
      ], SplitCharges()),
      throwsArgumentError,
    );
  });

  test('unassigned item indexes finds empty items', () {
    expect(
      SplitMath.unassignedItemIndexes([
        item('5.00', {'me'}),
        item('4.00'),
      ]),
      [1],
    );
  });

  test('owner spending subtracts friends', () {
    expect(
      SplitMath.ownerSpending(d('120.00'), d('80.00')).toStringAsFixed(2),
      '40.00',
    );
  });

  test('owner spending never negative', () {
    expect(
      SplitMath.ownerSpending(d('50.00'), d('80.00')).toStringAsFixed(2),
      '0.00',
    );
  });

  test('RM 10.00 shared by 3 gives out every cent', () {
    final shares = SplitMath.shares([
      item('10.00', {'a', 'b', 'c'}),
    ], SplitCharges());
    expect(sum(shares.values), d('10.00'));
    // Values and key order from the Kotlin result: a=3.33, b=3.33, c=3.33, me=0.01.
    expect(shares.keys.toList(), ['a', 'b', 'c', 'me']);
    expect(text(shares), {'me': '0.01', 'a': '3.33', 'b': '3.33', 'c': '3.33'});
  });

  test('rounding overshoot takes a cent back from the biggest gainer', () {
    // Values from the Kotlin result: a=3.38, b=3.35, c=3.38, me=0.00.
    final shares = SplitMath.shares([
      item('10.00', {'a', 'b', 'c'}),
      item('0.05', {'c', 'a'}),
    ], SplitCharges(serviceCharge: d('0.07'), discount: d('0.01')));
    expect(text(shares), {'me': '0.00', 'a': '3.38', 'b': '3.35', 'c': '3.38'});
  });
}
