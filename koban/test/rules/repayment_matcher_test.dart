import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/repayment_matcher.dart';

OpenDebtRef debt(String id, String personId, String name, String amount) =>
    OpenDebtRef(
      debtId: id,
      personId: personId,
      personName: name,
      amount: Decimal.parse(amount),
    );

final tie = [
  debt('da', 'a', 'Aisyah', '10.00'),
  debt('db', 'b', 'Ben', '10.00'),
];

void main() {
  test('match single debt exact', () {
    expect(
      RepaymentMatcher.match(
          Decimal.parse('7.38'), null, [debt('d1', 'a', 'Aisyah', '7.38')]),
      ['d1'],
    );
  });

  test('match several whole debts same person', () {
    expect(
      RepaymentMatcher.match(Decimal.parse('19.38'), null, [
        debt('d1', 'a', 'Aisyah', '7.38'),
        debt('d2', 'a', 'Aisyah', '12.00'),
      ]),
      ['d1', 'd2'],
    );
  });

  test('match never mixes people', () {
    expect(
      RepaymentMatcher.match(Decimal.parse('11.27'), null, [
        debt('d1', 'a', 'Aisyah', '7.38'),
        debt('d2', 'b', 'Ben', '3.89'),
      ]),
      <String>[],
    );
  });

  test('match prefers name match', () {
    expect(
      RepaymentMatcher.match(Decimal.parse('10'), 'AISYAH NUR RAHMAN', tie),
      ['da'],
    );
  });

  test('match ambiguous without name returns empty', () {
    expect(
        RepaymentMatcher.match(Decimal.parse('10.00'), null, tie), <String>[]);
  });

  test('match no subset returns empty', () {
    expect(
      RepaymentMatcher.match(
          Decimal.parse('7.00'), null, [debt('d1', 'a', 'Aisyah', '7.38')]),
      <String>[],
    );
  });
}
