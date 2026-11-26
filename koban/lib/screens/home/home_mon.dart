import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import '../../data/database.dart';
import '../../rules/periods.dart';
import '../../rules/types.dart';
import '../../theme/mon.dart';

/// What Mon says in the band: a face, one short dry line, and the plain message.
class MonSay {
  const MonSay(this.face, this.line, [this.detail]);

  final MonFace face;
  final String line;
  final String? detail;
}

/// The title of Home: the date in Malaysia, such as "Thu, 26 Nov".
String dateTitle(DateTime now) =>
    DateFormat('EEE, d MMM', 'en_US').format(GroupPeriodMath.malaysiaDay(now));

/// The spent total of each of the 7 days from [weekStart] (a Monday, local midnight).
/// Money received does not count.
List<Decimal> spentPerDay(List<Expense> expenses, DateTime weekStart) {
  final starts = [
    for (var i = 0; i < 7; i++)
      DateTime(
        weekStart.year,
        weekStart.month,
        weekStart.day + i,
      ).millisecondsSinceEpoch,
  ];
  final totals = List.filled(7, Decimal.zero);
  for (final e in expenses) {
    if (e.transactionType != TransactionType.withdraw) continue;
    final day = starts.lastIndexWhere((s) => s <= e.notificationPostTime);
    if (day < 0) continue;
    totals[day] += e.countedAmount ?? e.amount;
  }
  return totals;
}

/// Picks Mon's face and line for Home. The second line of the bubble is the tracking state. The first fact that holds wins: a problem to fix,
/// then payments to check, then the first payment, then the week against last week.
MonSay homeMon({
  required bool trackingOn,
  required bool listensToNoApp,
  required int waitingCount,
  required bool hasAnyPayment,
  required Decimal weekSpent,
  required Decimal lastWeekSoFar,
}) {
  if (!trackingOn) {
    return const MonSay(MonFace.worry, 'I cannot see your payments.');
  }
  if (listensToNoApp) {
    return const MonSay(MonFace.worry, 'I listen to no app.');
  }
  if (waitingCount > 0) {
    return MonSay(
      MonFace.idle,
      waitingCount == 1 ? 'A payment is waiting.' : 'Payments are waiting.',
    );
  }
  if (!hasAnyPayment) {
    return const MonSay(MonFace.idle, 'Nothing here yet.');
  }
  if (lastWeekSoFar > Decimal.zero && weekSpent < lastWeekSoFar) {
    return const MonSay(MonFace.happy, 'You spent less than last week.');
  }
  if (weekSpent > lastWeekSoFar && lastWeekSoFar > Decimal.zero) {
    return const MonSay(MonFace.idle, 'More than last week so far.');
  }
  return const MonSay(MonFace.idle, 'A quiet week so far.');
}
