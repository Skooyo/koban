import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/data/converters.dart';
import 'package:koban/rules/types.dart';

void main() {
  test('money is stored as text with 2 decimals like Kotlin', () {
    const c = MoneyConverter();
    expect(c.toSql(Decimal.parse('12.5')), '12.50');
    expect(c.toSql(Decimal.parse('1234')), '1234.00');
    expect(c.toSql(Decimal.parse('-0.02')), '-0.02');
    expect(c.toSql(Decimal.parse('0.005')), '0.01');
    expect(c.toSql(Decimal.parse('-0.005')), '-0.01');
    expect(c.fromSql('12.50'), Decimal.parse('12.50'));
    expect(c.fromSql('7'), Decimal.parse('7.00'));
  });
  test('enum converters store the Kotlin constant names', () {
    expect(const ExpenseStatusConverter().toSql(ExpenseStatus.autoSaved), 'AUTO_SAVED');
    expect(const ExpenseStatusConverter().fromSql('DISMISSED'), ExpenseStatus.dismissed);
    expect(const TransactionTypeConverter().toSql(TransactionType.receive), 'RECEIVE');
    expect(const ParseConfidenceConverter().fromSql('LOW'), ParseConfidence.low);
    expect(const CaptureFormatConverter().toSql(CaptureFormat.unknown), 'UNKNOWN');
    expect(const DebtStatusConverter().fromSql('PAID'), DebtStatus.paid);
  });
}
