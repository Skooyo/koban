/// Direction of money for a transaction.
enum TransactionType { withdraw, receive }

/// How sure the parser is about a result.
enum ParseConfidence { high, medium, low }

/// Life state of a saved expense.
enum ExpenseStatus { autoSaved, edited, dismissed }

/// Tells if a rule knew the text format or used the generic fallback.
enum CaptureFormat { known, unknown }
