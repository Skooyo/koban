import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/ui/amount_input.dart';

void main() {
  test('an empty or zero text gives no amount', () {
    expect(AmountInput.toAmount(''), isNull);
    expect(AmountInput.toAmount('0.'), isNull);
    expect(AmountInput.toAmount('0.00'), isNull);
  });

  test('a text gives an amount with two decimal places', () {
    expect(AmountInput.toAmount('12.5'), Decimal.parse('12.50'));
  });

  test('an amount keeps two decimal places in the text', () {
    expect(AmountInput.fromAmount(Decimal.parse('12.50')), '12.50');
  });

  test('a zero amount gives an empty text', () {
    expect(AmountInput.fromAmount(Decimal.parse('0.00')), '');
  });
}
