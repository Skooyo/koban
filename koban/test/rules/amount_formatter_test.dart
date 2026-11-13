import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/amount_formatter.dart';

void main() {
  test('to money rounds to two decimals', () {
    expect(
      AmountFormatter.toMoney(Decimal.parse('14.234')),
      Decimal.parse('14.23'),
    );
    expect(
      AmountFormatter.toMoney(Decimal.parse('14.235')),
      Decimal.parse('14.24'),
    );
  });

  test('format display always shows two decimals', () {
    expect(AmountFormatter.formatDisplay(Decimal.parse('10')), '10.00');
    expect(AmountFormatter.formatDisplay(Decimal.parse('14.5')), '14.50');
  });

  test(
    'format grouped uses thousands separator whatever the device locale',
    () {
      expect(
        AmountFormatter.formatGrouped(Decimal.parse('1284.1')),
        '1,284.10',
      );
      expect(AmountFormatter.formatGrouped(Decimal.parse('0.499')), '0.50');
    },
  );

  test('parse input normalizes input', () {
    expect(AmountFormatter.parseInput('1.234'), Decimal.parse('1.23'));
    expect(AmountFormatter.parseInput('1,234.56'), Decimal.parse('1234.56'));
  });

  test('parse input invalid returns null', () {
    expect(AmountFormatter.parseInput(''), isNull);
    expect(AmountFormatter.parseInput('abc'), isNull);
  });

  test('input with thousands separators parses like Kotlin', () {
    expect(AmountFormatter.parseInput('1,234'), Decimal.parse('1234'));
    expect(
      AmountFormatter.toMoney(Decimal.parse('1234.5')).toStringAsFixed(2),
      '1234.50',
    );
  });
}
