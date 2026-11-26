import 'package:decimal/decimal.dart';

import '../rules/periods.dart';
import 'database.dart';
import 'watch.dart';

/// How a category stands against its limit.
enum BudgetState {
  /// Under 80% of the limit.
  under,

  /// 80% to 99% of the limit.
  warn,

  /// 100% of the limit or more.
  over,
}

/// One budgeted category in one month.
class CategoryBudget {
  const CategoryBudget({
    required this.category,
    required this.limit,
    required this.spent,
  });

  final Category category;

  /// The limit that applies in the month. Always above zero.
  final Decimal limit;

  /// The MYR money out of the category in the month.
  final Decimal spent;

  BudgetState get state {
    if (spent >= limit) return BudgetState.over;
    // 80% or more: spent / limit >= 4 / 5, with no division.
    if (spent * Decimal.fromInt(5) >= limit * Decimal.fromInt(4)) {
      return BudgetState.warn;
    }
    return BudgetState.under;
  }

  /// The amount above the limit. Zero when the category is not over.
  Decimal get over => spent > limit ? spent - limit : Decimal.zero;
}

/// The budgets of one month: only the categories that have a limit in that month.
class BudgetMonth {
  const BudgetMonth({required this.month, required this.items});

  final YearMonth month;

  /// The budgeted categories, ordered by category name.
  final List<CategoryBudget> items;

  bool get isEmpty => items.isEmpty;

  /// The sum of the limits.
  Decimal get totalLimit => items.fold(Decimal.zero, (sum, i) => sum + i.limit);

  /// The money out of the budgeted categories only.
  Decimal get totalSpent => items.fold(Decimal.zero, (sum, i) => sum + i.spent);

  /// The count of categories over their limit.
  int get overCount => items.where((i) => i.state == BudgetState.over).length;
}

/// The personal monthly limits of the categories (issue #33).
/// Months are calendar months in Malaysia time. Limits are MYR only for now.
class BudgetRepository {
  BudgetRepository(this._db, {this._now = DateTime.now});

  final KobanDatabase _db;
  final DateTime Function() _now;

  static const currency = 'MYR';

  /// The current month in Malaysia time.
  YearMonth get currentMonth {
    final day = GroupPeriodMath.malaysiaDay(_now());
    return YearMonth(day.year, day.month);
  }

  /// The budgets of [month] (default: the current month). The stream emits again after
  /// a change of a payment, a limit or a category. It does not emit at the turn of the month.
  Stream<BudgetMonth> watchMonth([YearMonth? month]) => watchTables(_db, {
    _db.budgetLimits,
    _db.expenses,
    _db.categories,
  }, () => getMonth(month));

  Future<BudgetMonth> getMonth([YearMonth? month]) async {
    final m = month ?? currentMonth;
    final limits = _limitsIn(await _db.allLimitRows(currency).get(), m);
    if (limits.isEmpty) return BudgetMonth(month: m, items: const []);
    final spent = {
      for (final r
          in await _db
              .spentByCategoryIn(
                currency,
                _startMs(m),
                _startMs(m.plusMonths(1)),
              )
              .get())
        r.categoryId: r.total,
    };
    final categories = {
      for (final c in await _db.allCategories().get()) c.id: c,
    };
    return BudgetMonth(
      month: m,
      items: [
        // allCategories is ordered by name.
        for (final c in categories.values)
          if (limits[c.id] case final limit?)
            CategoryBudget(
              category: c,
              limit: limit,
              spent: spent[c.id] ?? Decimal.zero,
            ),
      ],
    );
  }

  /// The limit of each category now. A category with no limit is not in the map.
  Stream<Map<String, Decimal>> watchLimits() =>
      watchTables(_db, {_db.budgetLimits}, () async {
        return _limitsIn(await _db.allLimitRows(currency).get(), currentMonth);
      });

  /// Sets the limit of [categoryId] from the current month on. The whole current month counts.
  /// An amount of zero or less removes the limit.
  Future<void> setLimit(String categoryId, Decimal amount) {
    if (amount <= Decimal.zero) return clearLimit(categoryId);
    return _write(categoryId, amount);
  }

  /// Removes the limit of [categoryId] from the current month on. Past months keep their limit.
  Future<void> clearLimit(String categoryId) => _write(categoryId, null);

  Future<void> _write(String categoryId, Decimal? amount) =>
      _db.transaction(() async {
        final month = currentMonth.toString();
        final rows = (await _db.limitRowsOfCategory(categoryId).get()).where(
          (r) => r.currency == currency,
        );
        if (amount == null) {
          // With no older limit, a removal needs no row: it only drops the row of this month.
          if (!rows.any((r) => r.startMonth.compareTo(month) < 0)) {
            await _db.deleteLimitRow(categoryId, currency, month);
            return;
          }
        }
        await _db
            .into(_db.budgetLimits)
            .insertOnConflictUpdate(
              BudgetLimit(
                categoryId: categoryId,
                currency: currency,
                startMonth: month,
                amount: amount,
              ),
            );
      });

  /// The limit of each category in [month]: the latest row that starts in [month] or earlier.
  /// A row with no amount removes the limit.
  static Map<String, Decimal> _limitsIn(
    List<BudgetLimit> rows,
    YearMonth month,
  ) {
    final key = month.toString();
    final latest = <String, BudgetLimit>{};
    for (final r in rows) {
      if (r.startMonth.compareTo(key) > 0) continue;
      final seen = latest[r.categoryId];
      if (seen == null || seen.startMonth.compareTo(r.startMonth) < 0) {
        latest[r.categoryId] = r;
      }
    }
    return {for (final r in latest.values) r.categoryId: ?r.amount};
  }

  static int _startMs(YearMonth m) =>
      GroupPeriodMath.malaysiaDayStartMs(DateTime.utc(m.year, m.month, 1));
}
