final _digitsAfterLabel = RegExp(
  r'\b(ending(?:\s+with)?|no\.)(\s*)(\d{4,})',
  caseSensitive: false,
);

/// [text] with each card or account number hidden but its last 2 digits:
/// "Visa ending 1234" becomes "Visa ending ••34". For display only.
String maskCardDigits(String text) => text.replaceAllMapped(
  _digitsAfterLabel,
  (m) => '${m[1]}${m[2]}••${m[3]!.substring(m[3]!.length - 2)}',
);
