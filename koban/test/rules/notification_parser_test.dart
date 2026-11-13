import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/notification_parser.dart';
import 'package:koban/rules/types.dart';

Decimal d(String s) => Decimal.parse(s);

void main() {
  test('parse standard RM with space', () {
    final result = NotificationParser.parse('You spent RM 14.23 at Starbucks');
    expect(result, isNotNull);
    expect(result!.amount, d('14.23'));
    expect(result.merchant, 'Starbucks');
    expect(result.currency, 'MYR');
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse RM without space', () {
    final result = NotificationParser.parse('Payment of RM14.23 successful');
    expect(result, isNotNull);
    expect(result!.amount, d('14.23'));
  });

  test('parse MYR currency', () {
    final result = NotificationParser.parse(
      'Debited MYR 1,234.56 from account',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('1234.56'));
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse negative indicator', () {
    final result = NotificationParser.parse('Transaction: - RM 50.00');
    expect(result, isNotNull);
    expect(result!.amount, d('50.00'));
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse multiple amounts gives low confidence', () {
    final result = NotificationParser.parse(
      'RM 10.00 spent. Balance RM 500.00',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('10.00'));
    expect(result.confidence, ParseConfidence.low);
  });

  test('parse no amount returns null', () {
    expect(NotificationParser.parse('Your payment was successful'), isNull);
  });

  test('parse GrabPay style merchant from body', () {
    final result = NotificationParser.parse('RM 8.50 paid to ABC Mart');
    expect(result, isNotNull);
    expect(result!.amount, d('8.50'));
    expect(result.merchant, 'ABC Mart');
  });

  test('parse quoted merchant to pattern', () {
    final result = NotificationParser.parse(
      'Payment successful. To "ABC Mart" RM 12.34',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('12.34'));
    expect(result.merchant, 'ABC Mart');
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse TNG style merchant from body', () {
    final result = NotificationParser.parse(
      'You have paid RM 25.00 to Merchant XYZ',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('25.00'));
    expect(result.merchant, 'Merchant XYZ');
    expect(result.confidence, ParseConfidence.high);
  });

  test('normalize amount strips commas and scales', () {
    expect(NotificationParser.normalizeAmount('1,234.56'), d('1234.56'));
    expect(NotificationParser.normalizeAmount('10'), d('10.00'));
  });

  test('parse received detects receive type', () {
    final result = NotificationParser.parse(
      'You received RM 100.00 in your wallet',
    );
    expect(result, isNotNull);
    expect(result!.transactionType, TransactionType.receive);
  });

  test('parse paid detects withdraw type', () {
    final result = NotificationParser.parse('You paid RM 25.00 to Merchant');
    expect(result, isNotNull);
    expect(result!.transactionType, TransactionType.withdraw);
  });

  test('parse transfer successful style', () {
    final result = NotificationParser.parse(
      'RM 1.00 has been successfully transferred to AISYAH NUR RAHMAN',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('1.00'));
    expect(result.merchant, 'AISYAH NUR RAHMAN');
    expect(result.transactionType, TransactionType.withdraw);
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse Maybank transfer style', () {
    final result = NotificationParser.parse(
      "You've transferred RM 2.00 to AISYAH NUR RAHMAN",
    );
    expect(result, isNotNull);
    expect(result!.amount, d('2.00'));
    expect(result.merchant, 'AISYAH NUR RAHMAN');
    expect(result.transactionType, TransactionType.withdraw);
    expect(result.confidence, ParseConfidence.high);
  });

  test('parse Maybank spend at strips card tail', () {
    final result = NotificationParser.parse(
      'RM 12.50 spent at KK - SUPER MART - UMN with your Maybank Debit Card Visa ending with 3729',
    );
    expect(result, isNotNull);
    expect(result!.amount, d('12.50'));
    expect(result.merchant, 'KK - SUPER MART - UMN');
  });

  test('find all amounts deduplicates', () {
    final amounts = NotificationParser.findAllAmounts(
      'RM 10.00 and RM 10.00 again',
    );
    expect(amounts.length, 1);
    expect(amounts.first, d('10.00'));
  });

  test('text with a non-breaking space and mixed case parses like Kotlin', () {
    final r = NotificationParser.parse(
      'Pembayaran RM 12.50 kepada KEDAI Café berjaya',
    );
    // The desktop JVM gives null (its \s is ASCII only). Android ICU \s matches U+00A0 like Dart, so 12.50 is the Android result.
    expect(r?.amount, d('12.50'));
  });
}
