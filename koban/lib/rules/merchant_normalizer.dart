/// Clean shop and person names from bank and wallet notifications.
/// Card and account tails, for example "with your Maybank Debit Card ending with 3729",
/// are not part of the name.
abstract final class MerchantNormalizer {
  static final List<RegExp> _trailingJunk = [
    RegExp(r'\s+with\s+your\b.*$', caseSensitive: false),
    RegExp(r'\s+using\s+your\b.*$', caseSensitive: false),
    RegExp(r'\s+via\s+your\b.*$', caseSensitive: false),
    RegExp(
        r'\s+from\s+your\s+(?:maybank|cimb|rhb|hlb|public|bank|debit|credit|visa|mastercard|card|account)\b.*$',
        caseSensitive: false),
    RegExp(r'\s+ending\s+with\s+\d+.*$', caseSensitive: false),
    RegExp(r'\s+ending\s+\*+\d+.*$', caseSensitive: false),
    RegExp(r'\s+\(\s*(?:ref|txn|transaction|auth).*$', caseSensitive: false),
    RegExp(r'\s+ref(?:erence)?[\s.:#].*$', caseSensitive: false),
  ];

  static const String _months = 'jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec';

  /// Dates and times that banks add to the name. Digits inside a name stay.
  static final List<RegExp> _dateTime = [
    RegExp(r'[\s,]*\b\d{1,2}:\d{2}(?::\d{2})?(?:\s*[ap]m)?\b',
        caseSensitive: false),
    RegExp(r'(?:\s+on)?\s+\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b',
        caseSensitive: false),
    RegExp(r'(?:\s+on)?\s+\d{1,2}\s+(?:' + _months + r')[a-z]*\.?,?\s+\d{2,4}\b',
        caseSensitive: false),
  ];

  static final RegExp _manySpaces = RegExp(r'\s{2,}');

  /// Return the cleaned name, or null if it is blank or shorter than 2 characters.
  static String? clean(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    var value = _trimChars(raw.trim(), '"\'“”‘’').trim();

    for (final pattern in _dateTime) {
      value = value.replaceAll(pattern, '').trim();
    }
    for (final pattern in _trailingJunk) {
      value = value.replaceAll(pattern, '').trim();
    }

    value = _trimChars(value, '-:·•,;|')
        .replaceAll(_manySpaces, ' ')
        .trim();

    return value.length >= 2 ? value : null;
  }

  /// Remove the given characters from both ends, like Kotlin String.trim(chars).
  static String _trimChars(String s, String chars) {
    var start = 0;
    var end = s.length;
    while (start < end && chars.contains(s[start])) {
      start++;
    }
    while (end > start && chars.contains(s[end - 1])) {
      end--;
    }
    return s.substring(start, end);
  }
}
