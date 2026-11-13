import 'package:decimal/decimal.dart';

import 'amount_formatter.dart';
import 'repayment_matcher.dart';

/// What one person owes, or is owed.
sealed class Balance {
  const Balance();
}

/// The person owes you [amount].
final class PaysYou extends Balance {
  const PaysYou(this.amount);
  final Decimal amount;

  @override
  bool operator ==(Object other) => other is PaysYou && other.amount == amount;

  @override
  int get hashCode => Object.hash(PaysYou, amount);
}

/// You owe the person [amount].
final class YouPay extends Balance {
  const YouPay(this.amount);
  final Decimal amount;

  @override
  bool operator ==(Object other) => other is YouPay && other.amount == amount;

  @override
  int get hashCode => Object.hash(YouPay, amount);
}

/// Open items exist but the net is zero.
final class Even extends Balance {
  const Even();

  @override
  bool operator ==(Object other) => other is Even;

  @override
  int get hashCode => (Even).hashCode;
}

/// Nothing is open.
final class AllPaid extends Balance {
  const AllPaid();

  @override
  bool operator ==(Object other) => other is AllPaid;

  @override
  int get hashCode => (AllPaid).hashCode;
}

/// Group of a person on the people list. The Kotlin name is PeopleMath.Group.
enum PeopleGroup { youOwe, owesYou, others }

/// A person who can match a payment. The Kotlin name is PeopleMath.SettleCandidate.
class SettleCandidate {
  const SettleCandidate(this.personId, this.name, this.net);
  final String personId;
  final String name;
  final Decimal net;
}

/// Pure rules for the people list and person screen.
abstract final class PeopleMath {
  static String normalizedName(String name) => name
      .trim()
      // Kotlin \s is ASCII only. Dart \s also matches Unicode spaces.
      .replaceAll(RegExp(r'[ \t\n\x0B\f\r]+'), ' ')
      .toLowerCase();

  static Decimal net(List<Decimal> owedToMe, List<Decimal> iOwe) =>
      AmountFormatter.toMoney(_sum(owedToMe) - _sum(iOwe));

  static Balance balance(List<Decimal> owedToMe, List<Decimal> iOwe) {
    if (owedToMe.isEmpty && iOwe.isEmpty) return const AllPaid();
    final n = net(owedToMe, iOwe);
    return switch (n.sign) {
      1 => PaysYou(n),
      -1 => YouPay(-n),
      _ => const Even(),
    };
  }

  static String statusLine(
    String name,
    Balance balance, {
    required bool hasQr,
  }) => switch (balance) {
    PaysYou(:final amount) => 'Pays you ${_money(amount)}',
    YouPay(:final amount) => 'You pay ${_money(amount)}',
    Even() => "You're even",
    AllPaid() => hasQr ? 'All paid' : 'No QR saved yet',
  };

  static String headline(String name, Balance balance) => switch (balance) {
    PaysYou(:final amount) => '$name pays you ${_money(amount)}',
    YouPay(:final amount) => 'You pay $name ${_money(amount)}',
    Even() => "You're even",
    AllPaid() => 'All paid',
  };

  static PeopleGroup group(Balance balance) => switch (balance) {
    YouPay() => PeopleGroup.youOwe,
    PaysYou() => PeopleGroup.owesYou,
    _ => PeopleGroup.others,
  };

  /// The person whose positive net equals [amount]. The sender name breaks a tie.
  static String? settleMatch(
    Decimal amount,
    String? senderName,
    List<SettleCandidate> candidates,
  ) {
    final hits = candidates
        .where((c) => c.net.sign > 0 && c.net == amount)
        .toList();
    if (hits.length <= 1) return hits.isEmpty ? null : hits.single.personId;
    final senderWords = RepaymentMatcher.words(senderName ?? '');
    final named = hits
        .where((h) => RepaymentMatcher.words(h.name).any(senderWords.contains))
        .toList();
    return named.length == 1 ? named.single.personId : null;
  }

  static Decimal _sum(List<Decimal> values) =>
      values.fold(Decimal.zero, (s, v) => s + v);

  static String _money(Decimal amount) =>
      'RM ${AmountFormatter.formatGrouped(amount)}';
}
