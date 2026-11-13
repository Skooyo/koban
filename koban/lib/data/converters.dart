import 'package:decimal/decimal.dart';
import 'package:drift/drift.dart';

import '../rules/amount_formatter.dart';
import '../rules/types.dart';

/// Stores money as text with 2 decimals, the same as Room (for example "12.50").
class MoneyConverter extends TypeConverter<Decimal, String> {
  const MoneyConverter();

  @override
  Decimal fromSql(String fromDb) =>
      AmountFormatter.toMoney(Decimal.parse(fromDb));

  @override
  String toSql(Decimal value) =>
      AmountFormatter.toMoney(value).toStringAsFixed(2);
}

/// Stores a [TransactionType] as the Kotlin constant name.
class TransactionTypeConverter extends TypeConverter<TransactionType, String> {
  const TransactionTypeConverter();

  @override
  TransactionType fromSql(String fromDb) => TransactionType.fromDbName(fromDb);

  @override
  String toSql(TransactionType value) => value.dbName;
}

/// Stores a [ParseConfidence] as the Kotlin constant name.
class ParseConfidenceConverter extends TypeConverter<ParseConfidence, String> {
  const ParseConfidenceConverter();

  @override
  ParseConfidence fromSql(String fromDb) => ParseConfidence.fromDbName(fromDb);

  @override
  String toSql(ParseConfidence value) => value.dbName;
}

/// Stores an [ExpenseStatus] as the Kotlin constant name.
class ExpenseStatusConverter extends TypeConverter<ExpenseStatus, String> {
  const ExpenseStatusConverter();

  @override
  ExpenseStatus fromSql(String fromDb) => ExpenseStatus.fromDbName(fromDb);

  @override
  String toSql(ExpenseStatus value) => value.dbName;
}

/// Stores a [CaptureFormat] as the Kotlin constant name.
class CaptureFormatConverter extends TypeConverter<CaptureFormat, String> {
  const CaptureFormatConverter();

  @override
  CaptureFormat fromSql(String fromDb) => CaptureFormat.fromDbName(fromDb);

  @override
  String toSql(CaptureFormat value) => value.dbName;
}

/// Stores a [DebtStatus] as the Kotlin constant name.
class DebtStatusConverter extends TypeConverter<DebtStatus, String> {
  const DebtStatusConverter();

  @override
  DebtStatus fromSql(String fromDb) => DebtStatus.fromDbName(fromDb);

  @override
  String toSql(DebtStatus value) => value.dbName;
}
