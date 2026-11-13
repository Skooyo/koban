import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/merchant_normalizer.dart';

void main() {
  test('strips maybank debit card tail', () {
    expect(
        MerchantNormalizer.clean(
            'KK - SUPER MART - UMN with your Maybank Debit Card Visa ending with 3729'),
        'KK - SUPER MART - UMN');
  });

  test('leaves clean merchant alone', () {
    expect(MerchantNormalizer.clean('Starbucks'), 'Starbucks');
    expect(MerchantNormalizer.clean('AISYAH NUR RAHMAN'), 'AISYAH NUR RAHMAN');
  });

  test('blank becomes null', () {
    expect(MerchantNormalizer.clean('  '), isNull);
    expect(MerchantNormalizer.clean(null), isNull);
  });

  test('clean strips trailing date', () {
    expect(MerchantNormalizer.clean('KEDAI CONTOH 20/10/2026'), 'KEDAI CONTOH');
  });

  test('clean strips date and time', () {
    expect(MerchantNormalizer.clean('KEDAI CONTOH on 20 Oct 2026, 12:45'),
        'KEDAI CONTOH');
  });

  test('clean keeps numbers in name', () {
    expect(MerchantNormalizer.clean('99 SPEEDMART 1234'), '99 SPEEDMART 1234');
  });
}
