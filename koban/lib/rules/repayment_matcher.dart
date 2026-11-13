import 'package:decimal/decimal.dart';

/// One open debt of a person. Callers pass the list oldest first.
class OpenDebtRef {
  const OpenDebtRef({
    required this.debtId,
    required this.personId,
    required this.personName,
    required this.amount,
  });

  final String debtId;
  final String personId;
  final String personName;
  final Decimal amount;
}

/// Match a received payment to the open debts of one person.
abstract final class RepaymentMatcher {
  // ponytail: 2^12 subsets per person; switch to DP if people keep more open debts.
  static const int _maxDebtsPerPerson = 12;

  /// Return the debt ids to close, in input order.
  /// Return an empty list when no single person fits.
  static List<String> match(
    Decimal amount,
    String? senderName,
    List<OpenDebtRef> openDebts,
  ) {
    // Dart map literals keep insertion order, the same as Kotlin groupBy.
    final byPerson = <String, List<OpenDebtRef>>{};
    for (final debt in openDebts) {
      (byPerson[debt.personId] ??= []).add(debt);
    }
    final hits = <(OpenDebtRef, List<OpenDebtRef>)>[];
    for (final debts in byPerson.values) {
      final best = _bestSubset(amount, debts.take(_maxDebtsPerPerson).toList());
      if (best != null) hits.add((debts.first, best));
    }
    final chosen = hits.length <= 1
        ? hits
        : () {
            final senderWords = words(senderName ?? '');
            return hits
                .where((h) => words(h.$1.personName).any(senderWords.contains))
                .toList();
          }();
    if (chosen.length != 1) return [];
    return chosen.single.$2.map((d) => d.debtId).toList();
  }

  /// Fewest debts wins. A tie goes to the subset with the earliest debts.
  static List<OpenDebtRef>? _bestSubset(
    Decimal amount,
    List<OpenDebtRef> debts,
  ) {
    List<int>? best;
    for (var mask = 1; mask < (1 << debts.length); mask++) {
      final picked = [
        for (var i = 0; i < debts.length; i++)
          if ((mask >> i) & 1 == 1) i,
      ];
      final sum = picked.fold(Decimal.zero, (acc, i) => acc + debts[i].amount);
      if (sum != amount) continue;
      if (best == null || _isBetter(picked, best)) best = picked;
    }
    return best?.map((i) => debts[i]).toList();
  }

  static bool _isBetter(List<int> a, List<int> b) {
    if (a.length != b.length) return a.length < b.length;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return a[i] < b[i];
    }
    return false;
  }

  /// Lowercase words of three or more letters, in first-seen order.
  static Set<String> words(String text) => text
      .toLowerCase()
      .split(RegExp(r'[^\p{L}]+', unicode: true))
      .where((w) => w.length >= 3)
      .toSet();
}
