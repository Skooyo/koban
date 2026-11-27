import 'package:decimal/decimal.dart';

import '../../data/summaries.dart';
import '../../theme/mon.dart';
import '../home/home_mon.dart';

/// Picks Mon's face and line for Activity from what the screen shows now.
MonSay activityMon({
  required bool showAll,
  required bool searching,
  required bool filtered,
  required String monthLabel,
  required List<CategoryBreakdown> breakdown,
  List<String> overBudget = const [],
}) {
  if (searching || filtered) {
    return const MonSay(
      MonFace.idle,
      'Digging through your payments.',
      'Clear the search or filter to see all.',
    );
  }
  if (showAll) {
    return const MonSay(
      MonFace.idle,
      'Everything I have counted.',
      'All months, newest first.',
    );
  }
  final spent = breakdown.where((b) => b.total > Decimal.zero).toList()
    ..sort((a, b) => b.total.compareTo(a.total));
  if (spent.isEmpty) {
    return MonSay(MonFace.idle, 'Nothing in $monthLabel.', 'A quiet month.');
  }
  final all = spent.fold(Decimal.zero, (a, b) => a + b.total);
  final percent = (spent.first.total * Decimal.fromInt(100) / all)
      .toDecimal(scaleOnInfinitePrecision: 10)
      .round()
      .toBigInt()
      .toInt();
  return MonSay(
    MonFace.idle,
    '${spent.first.name} leads.',
    switch (overBudget.length) {
      0 => 'It is $percent% of what you spent.',
      1 => '${overBudget.first} is over its limit.',
      final n => '$n categories are over their limit.',
    },
  );
}
