/// Direction of money for a transaction.
enum TransactionType {
  withdraw('WITHDRAW'),
  receive('RECEIVE');

  const TransactionType(this.dbName);

  /// The name Room stores (the Kotlin enum constant name).
  final String dbName;

  static TransactionType fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown TransactionType: $name'),
  );
}

/// How sure the parser is about a result.
enum ParseConfidence {
  high('HIGH'),
  medium('MEDIUM'),
  low('LOW');

  const ParseConfidence(this.dbName);

  /// The name Room stores (the Kotlin enum constant name).
  final String dbName;

  static ParseConfidence fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown ParseConfidence: $name'),
  );
}

/// Life state of a saved expense.
enum ExpenseStatus {
  autoSaved('AUTO_SAVED'),
  edited('EDITED'),
  dismissed('DISMISSED');

  const ExpenseStatus(this.dbName);

  /// The name Room stores (the Kotlin enum constant name).
  final String dbName;

  static ExpenseStatus fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown ExpenseStatus: $name'),
  );
}

/// Tells if a rule knew the text format or used the generic fallback.
enum CaptureFormat {
  known('KNOWN'),
  unknown('UNKNOWN');

  const CaptureFormat(this.dbName);

  /// The name Room stores (the Kotlin enum constant name).
  final String dbName;

  static CaptureFormat fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown CaptureFormat: $name'),
  );
}

/// State of a split debt or an owed item.
enum DebtStatus {
  open('OPEN'),
  paid('PAID');

  const DebtStatus(this.dbName);

  /// The name Room stores (the Kotlin enum constant name).
  final String dbName;

  static DebtStatus fromDbName(String name) => values.firstWhere(
    (e) => e.dbName == name,
    orElse: () => throw ArgumentError('Unknown DebtStatus: $name'),
  );
}
