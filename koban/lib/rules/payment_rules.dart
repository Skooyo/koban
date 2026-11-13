import 'merchant_normalizer.dart';
import 'notification_parser.dart';
import 'parsed_expense.dart';
import 'types.dart';

/// Result of [PaymentRules.match].
sealed class RuleMatch {
  const RuleMatch();
}

/// The text has an amount. [format] tells if a strict rule or the catch-all read it.
final class Matched extends RuleMatch {
  const Matched(this.expense, this.format);

  final ParsedExpense expense;
  final CaptureFormat format;

  @override
  bool operator ==(Object other) =>
      other is Matched && other.expense == expense && other.format == format;

  @override
  int get hashCode => Object.hash(expense, format);

  @override
  String toString() => 'Matched($expense, $format)';
}

/// The text has no amount.
final class NoMatch extends RuleMatch {
  const NoMatch();

  @override
  bool operator ==(Object other) => other is NoMatch;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NoMatch';
}

/// Match a letter in upper and lower case. Dart has no inline flag to switch case
/// off for one part of a pattern. So each rule is case sensitive and its words
/// go through this function.
String _ci(String word) => word.replaceAllMapped(
  RegExp(r'[a-zA-Z]'),
  (m) => '[${m[0]!.toLowerCase()}${m[0]!.toUpperCase()}]',
);

class _Rule {
  _Rule(String pattern, this.type, [this.fixedMerchant])
    : regex = RegExp(pattern);

  final RegExp regex;
  final TransactionType type;
  final String? fixedMerchant;
}

/// Strict per-app regex rules first, then the catch-all [NotificationParser] for any text
/// with an RM or MYR amount (format unknown). Only a text with no amount is [NoMatch].
abstract final class PaymentRules {
  static const String _maybank = 'com.maybank2u.life';
  static const String _tng = 'my.com.tngdigital.ewallet';
  static const String _googleWallet = 'com.google.android.apps.walletnfcrel';

  static final String _amount =
      '${_ci('RM')}\\s*(?<amount>[\\d,]+(?:\\.\\d{1,2})?)';

  /// Shop name runs to a card tail, a "REF" or "View" sentence or the end.
  /// Dots inside names (Sdn. Bhd.) stay. A new sentence starts with a capital
  /// letter and a small letter. Only that check is case sensitive.
  static final String _merchant =
      '(?<merchant>.+?)(?='
      '\\s+${_ci('with')}\\s+${_ci('your')}\\b'
      '|\\s+${_ci('account')}\\s+${_ci('ending')}\\b'
      '|\\.+\\s*(?:${_ci('REF')}|${_ci('View')})\\b'
      '|\\.+\\s+(?!(?:${_ci('sdn')}|${_ci('bhd')}|${_ci('ltd')}|${_ci('co')}|${_ci('inc')})\\b)[A-Z][a-z]'
      '|\\.*\\s*\$)';

  /// Sender named before the verb, as in "ALI has transferred RM 10.00 to you".
  static const String _merchantFirst = '(?<merchant>.+?)';

  static final Map<String, List<_Rule>> _rules = {
    _maybank: [
      _Rule(
        '\\b${_ci('spent')}\\s+$_amount\\s+${_ci('at')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '\\b${_ci('payment')}\\s+${_ci('of')}\\s+$_amount\\s+${_ci('to')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '\\b${_ci('paid')}\\s+$_amount\\s+${_ci('to')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '\\b${_ci('transferred')}\\s+$_amount\\s+${_ci('to')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '\\b${_ci('withdrawn')}\\s+$_amount\\b',
        TransactionType.withdraw,
        'ATM withdrawal',
      ),
      _Rule(
        '\\b${_ci('received')}\\s+$_amount\\s+${_ci('from')}\\s+$_merchant',
        TransactionType.receive,
      ),
      _Rule(
        '\\b${_ci('received')}\\s+$_amount\\s+${_ci('in')}\\s+${_ci('your')}\\s+${_ci('account')}\\b',
        TransactionType.receive,
      ),
    ],
    _tng: [
      _Rule(
        '\\b${_ci('paid')}\\s+$_amount\\s+${_ci('to')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '$_amount\\s+${_ci('has')}\\s+${_ci('been')}\\s+${_ci('successfully')}\\s+${_ci('transferred')}\\s+${_ci('to')}\\s+$_merchant',
        TransactionType.withdraw,
      ),
      _Rule(
        '$_amount\\s+${_ci('received')}\\s+${_ci('from')}\\s+$_merchant',
        TransactionType.receive,
      ),
      _Rule(
        '^$_merchantFirst\\s+${_ci('has')}\\s+${_ci('transferred')}\\s+$_amount\\s+${_ci('to')}\\s+${_ci('you')}\\b',
        TransactionType.receive,
      ),
    ],
    // Card taps carry no shop name or direction, so they reach the catch-all
    // as "direction unclear".
    _googleWallet: [],
  };

  static final Set<String> knownPackages = _rules.keys.toSet();

  /// Apps whose matches start selected on the confirm screen.
  static const Set<String> preselectPackages = {_maybank, _tng};

  static RuleMatch match(String packageName, String text) {
    final appRules = _rules[packageName];
    if (appRules == null) return _matchGeneric(text);
    for (final rule in appRules) {
      final m = rule.regex.firstMatch(text);
      if (m == null) continue;
      final amount = NotificationParser.normalizeAmount(
        m.namedGroup('amount')!,
      );
      if (amount == null) continue;
      final merchant =
          rule.fixedMerchant ?? MerchantNormalizer.clean(_merchantOf(m));
      return Matched(
        ParsedExpense(
          amount: amount,
          currency: 'MYR',
          merchant: merchant,
          confidence: ParseConfidence.high,
          transactionType: rule.type,
        ),
        CaptureFormat.known,
      );
    }
    // Nothing with an amount is dropped; the owner swipes a promotion away on the card.
    return _matchGeneric(text);
  }

  /// A rule without a shop name group gives null, like Kotlin runCatching.
  static String? _merchantOf(RegExpMatch m) {
    try {
      return m.namedGroup('merchant');
    } on ArgumentError {
      return null;
    }
  }

  static RuleMatch _matchGeneric(String text) {
    final parsed = NotificationParser.parse(text);
    if (parsed == null) return const NoMatch();
    return Matched(parsed, CaptureFormat.unknown);
  }
}
