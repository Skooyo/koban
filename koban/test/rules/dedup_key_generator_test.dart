import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/dedup_key_generator.dart';

String _key(String amount, String? merchant, int postTime) =>
    DedupKeyGenerator.generate(
      packageName: 'com.app',
      amount: Decimal.parse(amount),
      merchant: merchant,
      postTime: postTime,
    );

void main() {
  const postTime = 1700000000000;

  test('same inputs same bucket produce same key', () {
    expect(
      _key('14.23', 'Starbucks', postTime),
      _key('14.23', 'Starbucks', postTime + 1000),
    );
  });

  test('different amounts produce different keys', () {
    expect(
      _key('14.23', 'Starbucks', postTime),
      isNot(_key('15.00', 'Starbucks', postTime)),
    );
  });

  test('different merchants same amount produce same key', () {
    expect(
      _key('14.23', 'Starbucks', postTime),
      _key('14.23', 'STARBUCKS SDN BHD', postTime),
    );
  });

  // Literal keys come from the Kotlin DedupKeyGenerator for the same inputs.
  test('keys equal the literal Kotlin keys', () {
    expect(
      _key('14.23', 'Starbucks', postTime),
      'd10f2db5bcdb8f6969af50de184b31e4b2d3221a855392eeaaa74863a5dce1c4',
    );
    expect(
      DedupKeyGenerator.generate(
        packageName: 'my.bank.app',
        amount: Decimal.parse('5'),
        merchant: null,
        postTime: postTime,
      ),
      '571d8a6c1f96751d90bbb9d8612944195b2e45e987d65217cdfb8c72177a8a1a',
    );
    expect(
      DedupKeyGenerator.generate(
        packageName: 'my.bank.app',
        amount: Decimal.parse('1234.5'),
        merchant: null,
        postTime: postTime - 1,
      ),
      '4986efa38a1a3b97c43b27e72e3c5cac8e4034f4caec2d9510968623e90b767c',
    );
  });

  test('lookback is 30 minutes in milliseconds', () {
    expect(DedupKeyGenerator.dedupLookbackMs(), 1800000);
  });
}
