import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/ui/amount_input.dart';

void main() {
  test('a digit on an empty text starts the number', () {
    expect(AmountInput.press('', '5'), '5');
  });

  test('a dot on an empty text adds a leading zero', () {
    expect(AmountInput.press('', '.'), '0.');
  });

  test('a digit after a zero replaces the zero', () {
    expect(AmountInput.press('0', '7'), '7');
    expect(AmountInput.press('0', '0'), '0');
  });

  test('a second dot is ignored', () {
    expect(AmountInput.press('12.', '.'), '12.');
  });

  test('a third decimal digit is ignored', () {
    expect(AmountInput.press('12.34', '5'), '12.34');
  });

  test('the ninth whole digit is allowed and the tenth is ignored', () {
    expect(AmountInput.press('12345678', '9'), '123456789');
    expect(AmountInput.press('123456789', '1'), '123456789');
    expect(AmountInput.press('123456789', '.'), '123456789.');
  });

  test('a key that is not a digit or a dot is ignored', () {
    expect(AmountInput.press('12', 'x'), '12');
  });

  test('backspace removes the last character', () {
    expect(AmountInput.backspace('12.5'), '12.');
    expect(AmountInput.backspace('1'), '');
    expect(AmountInput.backspace(''), '');
  });

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
