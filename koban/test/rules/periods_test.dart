import 'package:flutter_test/flutter_test.dart';
import 'package:koban/rules/periods.dart';

void main() {
  group('PeriodCalculator', () {
    test('week range is Monday to Sunday', () {
      final anchor = DateTime(2026, 6, 24, 15, 30);
      final (start, end) = PeriodCalculator.range(
        SpendingPeriod.week,
        anchor: anchor,
      );
      final s = DateTime.fromMillisecondsSinceEpoch(start);
      final e = DateTime.fromMillisecondsSinceEpoch(end);
      expect(s.weekday, DateTime.monday);
      expect(e.weekday, DateTime.monday);
      expect(e.difference(s).inDays, 7);
      expect(
        start <= anchor.millisecondsSinceEpoch &&
            anchor.millisecondsSinceEpoch < end,
        isTrue,
      );
    });

    test('month range is calendar month', () {
      final (start, end) = PeriodCalculator.range(
        SpendingPeriod.month,
        anchor: DateTime(2026, 6, 15, 12, 0),
      );
      final s = DateTime.fromMillisecondsSinceEpoch(start);
      final e = DateTime.fromMillisecondsSinceEpoch(end);
      expect(s.day, 1);
      expect(s.month, DateTime.june);
      expect(e.day, 1);
      expect(e.month, DateTime.july);
    });

    test('Sunday 23:59 is in the old week and Monday 00:00 in the new one', () {
      final sun = DateTime(2026, 11, 15, 23, 59);
      final mon = DateTime(2026, 11, 16, 0, 0);
      final (start, end) = PeriodCalculator.range(
        SpendingPeriod.week,
        anchor: sun,
      );
      expect(
        sun.millisecondsSinceEpoch >= start && sun.millisecondsSinceEpoch < end,
        isTrue,
      );
      expect(mon.millisecondsSinceEpoch >= end, isTrue);
    });
  });

  group('MonthNav', () {
    final current = YearMonth(2026, 10);

    test('previous crosses year boundary', () {
      expect(MonthNav.previous(YearMonth(2026, 1)), YearMonth(2025, 12));
    });

    test('next crosses year boundary', () {
      expect(MonthNav.next(YearMonth(2025, 12), current), YearMonth(2026, 1));
    });

    test('next is null on current month', () {
      expect(MonthNav.next(current, current), isNull);
    });

    test('next is null after current month', () {
      expect(MonthNav.next(YearMonth(2026, 11), current), isNull);
    });

    test('label is full month name and year', () {
      expect(MonthNav.label(current), 'October 2026');
    });
  });

  group('GroupPeriodMath', () {
    DateTime day(int y, int m, int d) => DateTime.utc(y, m, d);

    test('week starts on Monday', () {
      expect(
        GroupPeriodMath.start(day(2026, 11, 12), Period.week),
        day(2026, 11, 9),
      );
      expect(
        GroupPeriodMath.start(day(2026, 11, 9), Period.week),
        day(2026, 11, 9),
      );
      expect(
        GroupPeriodMath.start(day(2026, 11, 15), Period.week),
        day(2026, 11, 9),
      );
      expect(
        GroupPeriodMath.start(day(2026, 12, 2), Period.week),
        day(2026, 11, 30),
      );
    });

    test('month starts on the first', () {
      expect(
        GroupPeriodMath.start(day(2026, 11, 30), Period.month),
        day(2026, 11, 1),
      );
    });

    test('days left counts to the next start', () {
      expect(GroupPeriodMath.daysLeft(Period.week, today: day(2026, 11, 12)), 4);
      expect(GroupPeriodMath.daysLeft(Period.week, today: day(2026, 11, 15)), 1);
      expect(
        GroupPeriodMath.daysLeft(Period.month, today: day(2026, 11, 12)),
        19,
      );
      expect(
        GroupPeriodMath.daysLeft(Period.month, today: day(2027, 2, 28)),
        1,
      );
    });
  });
}
