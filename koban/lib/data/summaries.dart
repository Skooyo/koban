import 'package:decimal/decimal.dart';

import 'database.dart';

/// One category in a spending breakdown. A null [categoryId] is Uncategorized.
class CategoryBreakdown {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.colorHex,
    required this.total,
    required this.fraction,
    this.count = 0,
  });

  final String? categoryId;
  final String name;
  final String colorHex;
  final Decimal total;

  /// The share of all category totals, from 0 to 1, rounded to 4 decimals.
  final double fraction;

  /// How many Spent payments make up [total].
  final int count;
}

/// The spending of one day, week or month with its newest payments.
class PeriodSummary {
  const PeriodSummary({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.breakdown,
    required this.recentExpenses,
    this.periodStart = 0,
    this.periodEnd = 0,
    required this.received,
  });

  final String title;
  final String subtitle;
  final Decimal total;
  final List<CategoryBreakdown> breakdown;
  final List<Expense> recentExpenses;
  final int periodStart;
  final int periodEnd;
  final Decimal received;
}

/// The totals of one local month. [month0] is 0-based (0 = January).
class MonthSummary {
  const MonthSummary({
    required this.year,
    required this.month0,
    required this.label,
    required this.total,
    required this.received,
  });

  final int year;
  final int month0;
  final String label;
  final Decimal total;
  final Decimal received;
}

/// The total of one Monday-to-Sunday week. [endMs] is exclusive.
class WeekSummary {
  const WeekSummary({
    required this.startMs,
    required this.endMs,
    required this.label,
    required this.total,
  });

  final int startMs;
  final int endMs;
  final String label;
  final Decimal total;
}
