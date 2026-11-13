import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/types.dart';

void main() {
  test('transaction type names equal the Kotlin constants', () {
    expect(TransactionType.values.map((e) => e.dbName), [
      'WITHDRAW',
      'RECEIVE',
    ]);
    for (final e in TransactionType.values) {
      expect(TransactionType.fromDbName(e.dbName), e);
    }
    expect(() => TransactionType.fromDbName('withdraw'), throwsArgumentError);
  });

  test('parse confidence names equal the Kotlin constants', () {
    expect(ParseConfidence.values.map((e) => e.dbName), [
      'HIGH',
      'MEDIUM',
      'LOW',
    ]);
    for (final e in ParseConfidence.values) {
      expect(ParseConfidence.fromDbName(e.dbName), e);
    }
    expect(() => ParseConfidence.fromDbName('NONE'), throwsArgumentError);
  });

  test('expense status names equal the Kotlin constants', () {
    expect(ExpenseStatus.values.map((e) => e.dbName), [
      'AUTO_SAVED',
      'EDITED',
      'DISMISSED',
    ]);
    for (final e in ExpenseStatus.values) {
      expect(ExpenseStatus.fromDbName(e.dbName), e);
    }
    expect(() => ExpenseStatus.fromDbName('autoSaved'), throwsArgumentError);
  });

  test('capture format names equal the Kotlin constants', () {
    expect(CaptureFormat.values.map((e) => e.dbName), ['KNOWN', 'UNKNOWN']);
    for (final e in CaptureFormat.values) {
      expect(CaptureFormat.fromDbName(e.dbName), e);
    }
    expect(() => CaptureFormat.fromDbName(''), throwsArgumentError);
  });
}
