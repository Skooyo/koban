import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/screens/split/split_entry.dart';

Decimal d(String v) => Decimal.parse(v);

KeypadEntry type(List<PadKey> keys) =>
    keys.fold(const KeypadEntry(), (e, k) => e.press(k));

void main() {
  group('keypad', () {
    test('3 Times 2.70 is quantity 3, unit 2.70 and a line of RM 8.10', () {
      final e = type([
        PadKey.d3,
        PadKey.times,
        PadKey.d2,
        PadKey.dot,
        PadKey.d7,
        PadKey.d0,
      ]);
      expect((e.quantity, e.unit), (3, '2.70'));
      expect(e.linePrice, d('8.10'));
      expect(e.display, '3 × 2.70');
    });

    test(
      'a third decimal, a second dot and Times after a price change nothing',
      () {
        final e = type([
          PadKey.d1,
          PadKey.dot,
          PadKey.d2,
          PadKey.d5,
          PadKey.d9,
          PadKey.dot,
          PadKey.times,
        ]);
        expect((e.quantity, e.unit), (1, '1.25'));
      },
    );

    test('Delete after Times gives the typed quantity back as text', () {
      final e = type([PadKey.d1, PadKey.d2, PadKey.times, PadKey.back]);
      expect((e.quantity, e.unit), (1, '12'));
    });

    test(
      'a leading dot gets a zero, 00 adds two zeros, and a lone 0 is replaced',
      () {
        expect(type([PadKey.dot, PadKey.d5]).unit, '0.5');
        expect(type([PadKey.d4, PadKey.d00]).unit, '400');
        expect(type([PadKey.d0, PadKey.d7]).unit, '7');
      },
    );

    test('no price or a zero price has no line price', () {
      expect(type([PadKey.d2, PadKey.times]).linePrice, null);
      expect(type([PadKey.d0, PadKey.dot, PadKey.d0]).linePrice, null);
    });

    test('the stepper keeps the quantity between 1 and 999', () {
      final e = type([PadKey.d2]);
      expect(e.withQuantity(0).quantity, 1);
      expect(e.withQuantity(1200).quantity, 999);
      expect(e.withQuantity(4).linePrice, d('8.00'));
    });
  });

  group('charges', () {
    test('a rate is a percent of the subtotal to the sen', () {
      expect(chargeAmount(const RateCharge(10), d('74.50')), d('7.45'));
      expect(chargeAmount(const RateCharge(6), d('74.50')), d('4.47'));
      expect(chargeAmount(const RateCharge(8), d('33.33')), d('2.67'));
      expect(chargeAmount(FixedCharge(d('5.00')), d('74.50')), d('5.00'));
      expect(chargeAmount(const NoCharge(), d('74.50')), d('0'));
    });

    test('a stored amount is a rate only when the rate gives it exactly', () {
      expect(
        chargeFrom(d('7.45'), d('74.50'), serviceRates),
        const RateCharge(10),
      );
      expect(chargeFrom(d('5.96'), d('74.50'), sstRates), const RateCharge(8));
      expect(
        chargeFrom(d('7.40'), d('74.50'), serviceRates),
        FixedCharge(d('7.40')),
      );
      expect(chargeFrom(d('0'), d('74.50'), serviceRates), const NoCharge());
    });
  });

  test('rounding fills a gap of 5 sen or less and leaves a bigger gap', () {
    expect(autoRounding(d('86.40'), d('86.42')), d('-0.02'));
    expect(autoRounding(d('86.40'), d('86.35')), d('0.05'));
    expect(autoRounding(d('86.40'), d('86.34')), d('0'));
    expect(autoRounding(d('24.50'), d('24.00')), d('0'));
  });

  test('the missing item money takes the rates and the fixed charges out of the total', () {
    // 86.40 with 10% and 6%: a subtotal of 74.48, so 11.58 is not in the items yet.
    expect(
      missingItems(
        total: d('86.40'),
        itemsSum: d('62.90'),
        ratePercent: 16,
        fixed: d('0'),
      ),
      d('11.58'),
    );
    // A discount of 2.00 is a fixed charge of -2.00.
    expect(
      missingItems(
        total: d('20.00'),
        itemsSum: d('15.00'),
        ratePercent: 0,
        fixed: d('-2.00'),
      ),
      d('7.00'),
    );
    expect(
      missingItems(
        total: d('10.00'),
        itemsSum: d('12.00'),
        ratePercent: 0,
        fixed: d('0'),
      ),
      d('-2.00'),
    );
  });

  test('each of a split is the amount over the parts, to the sen', () {
    expect(eachOf(d('11.60'), 4), d('2.90'));
    expect(eachOf(d('10.00'), 3), d('3.33'));
  });
}
