import 'package:intl/intl.dart';

/// Spending period shown on the home screen.
enum SpendingPeriod { day, week, month }

/// Time ranges and labels for spending periods. Uses local time.
/// Months in this class are 0-based (0 = January), like the Kotlin source.
/// Ranges are start-inclusive and end-exclusive.
class PeriodCalculator {
  PeriodCalculator._();

  static final _dayLabel = DateFormat('EEE, d MMM yyyy', 'en_US');
  static final _shortDate = DateFormat('d MMM', 'en_US');
  static final _monthYear = DateFormat('MMMM yyyy', 'en_US');

  /// Start and end of the period that holds [anchor] (default: now), in ms.
  static (int, int) range(SpendingPeriod period, {DateTime? anchor}) {
    final a = anchor ?? DateTime.now();
    var start = DateTime(a.year, a.month, a.day);
    if (period == SpendingPeriod.week) {
      start = _alignToMonday(start);
    } else if (period == SpendingPeriod.month) {
      start = DateTime(a.year, a.month, 1);
    }
    final end = switch (period) {
      SpendingPeriod.day => DateTime(start.year, start.month, start.day + 1),
      SpendingPeriod.week => DateTime(start.year, start.month, start.day + 7),
      SpendingPeriod.month => DateTime(start.year, start.month + 1, 1),
    };
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  /// Start and end of a month. [month] is 0-based.
  static (int, int) rangeForMonth(int year, int month) {
    final start = DateTime(year, month + 1, 1);
    final end = DateTime(year, month + 2, 1);
    return (start.millisecondsSinceEpoch, end.millisecondsSinceEpoch);
  }

  /// Monday-to-Sunday weeks that touch the month. [month] is 0-based.
  static List<(int, int)> weeksInMonth(int year, int month) {
    final (monthStart, monthEnd) = rangeForMonth(year, month);
    final weeks = <(int, int)>[];
    var cursor = _alignToMonday(
      DateTime.fromMillisecondsSinceEpoch(monthStart),
    );
    while (cursor.millisecondsSinceEpoch < monthEnd) {
      final weekStart = cursor.millisecondsSinceEpoch;
      final next = DateTime(cursor.year, cursor.month, cursor.day + 7);
      final weekEnd = next.millisecondsSinceEpoch;
      if (weekEnd > monthStart && weekStart < monthEnd) {
        weeks.add((weekStart, weekEnd));
      }
      cursor = next;
    }
    return weeks;
  }

  static String weekLabel(int startMs, int endMs) =>
      'Mon ${_shortDate.format(DateTime.fromMillisecondsSinceEpoch(startMs))}'
      ' – '
      'Sun ${_shortDate.format(DateTime.fromMillisecondsSinceEpoch(endMs - 1))}';

  /// Label such as "October 2026". [month] is 0-based.
  static String monthLabel(int year, int month) =>
      _monthYear.format(DateTime(year, month + 1, 1));

  static String title(SpendingPeriod period) => switch (period) {
    SpendingPeriod.day => 'Today',
    SpendingPeriod.week => 'This week',
    SpendingPeriod.month => 'This month',
  };

  static String label(SpendingPeriod period, {DateTime? anchor}) {
    final a = anchor ?? DateTime.now();
    return switch (period) {
      SpendingPeriod.day => _dayLabel.format(a),
      SpendingPeriod.week => () {
        final (s, e) = range(SpendingPeriod.week, anchor: a);
        return weekLabel(s, e);
      }(),
      SpendingPeriod.month => _monthYear.format(a),
    };
  }

  /// Split 202610 into (2026, 9). The month in the result is 0-based.
  static (int, int) decodeYearMonth(int yearMonth) =>
      (yearMonth ~/ 100, yearMonth % 100 - 1);

  static DateTime _alignToMonday(DateTime d) =>
      DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
}

/// A year and a month. [month] is 1 to 12.
class YearMonth implements Comparable<YearMonth> {
  const YearMonth(this.year, this.month);

  final int year;
  final int month;

  YearMonth plusMonths(int n) {
    final i = year * 12 + (month - 1) + n;
    return YearMonth(i ~/ 12, i % 12 + 1);
  }

  @override
  int compareTo(YearMonth other) =>
      (year * 12 + month).compareTo(other.year * 12 + other.month);

  @override
  bool operator ==(Object other) =>
      other is YearMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);

  @override
  String toString() => '$year-${month.toString().padLeft(2, '0')}';
}

/// Month stepping for the Activity month bar. Next stops at the current month.
class MonthNav {
  MonthNav._();

  static final _label = DateFormat('MMMM yyyy', 'en_US');

  static YearMonth previous(YearMonth m) => m.plusMonths(-1);

  static YearMonth? next(YearMonth m, YearMonth current) =>
      m.compareTo(current) >= 0 ? null : m.plusMonths(1);

  static String label(YearMonth m) => _label.format(DateTime(m.year, m.month));
}

/// Period of a group budget.
enum Period {
  week('week'),
  month('month');

  const Period(this.key);
  final String key;
}

/// Group period math in Malaysia time (fixed UTC+8, no daylight saving).
/// Days are dates: a UTC DateTime at 00:00 stands for one calendar day.
class GroupPeriodMath {
  GroupPeriodMath._();

  /// Today's date in Malaysia.
  static DateTime todayInMalaysia() {
    final t = DateTime.now().toUtc().add(const Duration(hours: 8));
    return DateTime.utc(t.year, t.month, t.day);
  }

  /// First day of the period that holds [day]. Week starts on Monday.
  static DateTime start(DateTime day, Period period) => period == Period.week
      ? DateTime.utc(day.year, day.month, day.day - (day.weekday - 1))
      : DateTime.utc(day.year, day.month, 1);

  /// Days from [today] (default: today in Malaysia) to the next period start.
  static int daysLeft(Period period, {DateTime? today}) {
    final t = today ?? todayInMalaysia();
    final s = start(t, period);
    final next = period == Period.week
        ? DateTime.utc(s.year, s.month, s.day + 7)
        : DateTime.utc(s.year, s.month + 1, 1);
    return next.difference(DateTime.utc(t.year, t.month, t.day)).inDays;
  }
}
