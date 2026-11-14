import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart' hide Category;

import '../../app/app_services.dart';
import '../../data/activity_selection.dart';
import '../../data/category_repository.dart';
import '../../data/database.dart';
import '../../data/summaries.dart';
import '../../rules/periods.dart';
import '../../ui/category_donut.dart';

/// What the Activity tab shows. A port of `ActivityUiState`.
@immutable
class ActivityUiState {
  ActivityUiState({
    required this.month,
    this.canGoNext = false,
    Decimal? monthTotal,
    Decimal? monthReceived,
    this.weeks = const [],
    this.selectedWeek,
    this.expenses = const [],
    this.slices = const [],
    this.breakdown = const [],
    this.categoryNames = const {},
    this.categoryFilter,
    this.showAll = false,
  }) : monthTotal = monthTotal ?? Decimal.zero,
       monthReceived = monthReceived ?? Decimal.zero;

  final YearMonth month;
  final bool canGoNext;
  final Decimal monthTotal;
  final Decimal monthReceived;
  final List<WeekSummary> weeks;

  /// The start of the chosen week, in ms. Null shows the whole month.
  final int? selectedWeek;
  final List<Expense> expenses;
  final List<DonutSlice> slices;
  final List<CategoryBreakdown> breakdown;
  final Map<String, String> categoryNames;
  final String? categoryFilter;
  final bool showAll;
}

/// One month of the All view: its spent total (as the Month view total)
/// and its payments after the category filter.
class ActivityMonthGroup {
  const ActivityMonthGroup(
    this.month,
    this.total,
    this.received,
    this.expenses,
  );

  final YearMonth month;
  final Decimal total;
  final Decimal received;
  final List<Expense> expenses;
}

/// Spent in total and per category over the range the filter sheet shows.
class FilterTotals {
  FilterTotals([Decimal? total, this.breakdown = const []])
    : total = total ?? Decimal.zero;

  final Decimal total;
  final List<CategoryBreakdown> breakdown;
}

/// The payments, the totals, the weeks and the ring of one month (or week), before the category filter.
class _MonthData {
  const _MonthData(
    this.month,
    this.total,
    this.received,
    this.weeks,
    this.selectedWeek,
    this.expenses,
    this.breakdown,
  );

  final YearMonth month;
  final Decimal total;
  final Decimal received;
  final List<WeekSummary> weeks;
  final int? selectedWeek;
  final List<Expense> expenses;
  final List<CategoryBreakdown> breakdown;
}

/// The end of the all-time range. It is the largest 64-bit integer.
const _forever = 0x7fffffffffffffff;

/// The state of the Activity tab. A port of `ActivityViewModel.kt`.
/// The month, the week, the category filter and the All view live in [ActivitySelection].
class ActivityViewModel extends ChangeNotifier {
  ActivityViewModel(this._s) {
    _watched = _s.activitySelection.value;
    _s.activitySelection.addListener(_onSelection);
    _watchMonth();
    if (_watched.showAll) _watchAllTime();
    _subs.add(
      _s.categories.watchAll().listen((list) {
        _categories = list;
        notifyListeners();
      }),
    );
    _subs.add(
      _s.expenses.watchMonthlySummaries().listen((list) {
        _monthly = list;
        _rebuildAll();
        notifyListeners();
      }),
    );
    _subs.add(
      _s.expenses.watchAllActive().listen((list) {
        _allActive = list;
        _rebuildAll();
        notifyListeners();
      }),
    );
  }

  final AppServices _s;
  final List<StreamSubscription<Object?>> _subs = [];
  List<StreamSubscription<Object?>> _monthSubs = [];
  List<StreamSubscription<Object?>> _allTimeSubs = [];
  late Selection _watched;
  var _generation = 0;
  _MonthData? _data;
  List<Category> _categories = const [];
  List<MonthSummary>? _monthly;
  List<Expense>? _allActive;
  List<ActivityMonthGroup>? _allMonths;
  Decimal? _allTimeTotal;
  List<CategoryBreakdown>? _allTimeBreakdown;

  List<Category> get categories => _categories;

  YearMonth get _currentMonth {
    final n = _s.now();
    return YearMonth(n.year, n.month);
  }

  ActivityUiState get state {
    final sel = _s.activitySelection.value;
    final d = _data;
    final names = {for (final c in _categories) c.id: c.name};
    if (d == null) {
      return ActivityUiState(
        month: sel.month,
        categoryNames: names,
        categoryFilter: sel.categoryFilter,
        showAll: sel.showAll,
      );
    }
    return ActivityUiState(
      month: d.month,
      canGoNext: MonthNav.next(d.month, _currentMonth) != null,
      monthTotal: d.total,
      monthReceived: d.received,
      weeks: d.weeks,
      selectedWeek: d.selectedWeek,
      expenses: [
        for (final e in d.expenses)
          if (matchesCategory(e, sel.categoryFilter)) e,
      ],
      slices: donutSlices(d.breakdown),
      breakdown: d.breakdown,
      categoryNames: names,
      categoryFilter: sel.categoryFilter,
      showAll: sel.showAll,
    );
  }

  /// Every payment, newest first, split by month. Null while loading or in the Month view.
  List<ActivityMonthGroup>? get allMonths =>
      _s.activitySelection.value.showAll ? _allMonths : null;

  /// Totals for the filter sheet: the range of the ring (month or week) in the Month view, all time in the All view.
  FilterTotals get filterTotals {
    if (_s.activitySelection.value.showAll) {
      final total = _allTimeTotal;
      final breakdown = _allTimeBreakdown;
      return total == null || breakdown == null
          ? FilterTotals()
          : FilterTotals(total, breakdown);
    }
    final d = _data;
    return d == null ? FilterTotals() : FilterTotals(d.total, d.breakdown);
  }

  /// The months with payments, newest first, and the current month even when it is empty.
  List<MonthSummary> get sheetMonths {
    final months = _monthly ?? const <MonthSummary>[];
    final now = _currentMonth;
    if (months.any((m) => m.year == now.year && m.month0 == now.month - 1)) {
      return months;
    }
    final current = MonthSummary(
      year: now.year,
      month0: now.month - 1,
      label: MonthNav.label(now),
      total: Decimal.zero,
      received: Decimal.zero,
    );
    return [...months, current]
      ..sort((a, b) => (b.year * 12 + b.month0) - (a.year * 12 + a.month0));
  }

  void _onSelection() {
    final sel = _s.activitySelection.value;
    final old = _watched;
    _watched = sel;
    if (sel.month != old.month || sel.weekStart != old.weekStart) {
      _watchMonth();
    }
    if (sel.showAll != old.showAll) {
      if (sel.showAll) {
        _watchAllTime();
      } else {
        _cancelAll(_allTimeSubs);
        _allTimeSubs = [];
        _allTimeTotal = null;
        _allTimeBreakdown = null;
      }
    }
    _rebuildAll();
    notifyListeners();
  }

  /// Starts the streams of the shown month. Until all of them answer, the old data stays.
  void _watchMonth() {
    _cancelAll(_monthSubs);
    final generation = ++_generation;
    final month = _watched.month;
    final year = month.year;
    final month0 = month.month - 1;
    final (monthStart, monthEnd) = PeriodCalculator.rangeForMonth(year, month0);
    final weekRanges = PeriodCalculator.weeksInMonth(year, month0);
    final week = _watched.weekStart == null
        ? null
        : weekRanges.where((w) => w.$1 == _watched.weekStart).firstOrNull;
    final (listStart, listEnd) = week ?? (monthStart, monthEnd);
    // Full Monday-to-Sunday weeks reach into the next and the last month, so watch the whole span.
    final spanStart = weekRanges.firstOrNull?.$1 ?? monthStart;
    final spanEnd = weekRanges.lastOrNull?.$2 ?? monthEnd;

    Decimal? total;
    Decimal? received;
    ({List<WeekSummary> weeks, List<Expense> expenses})? span;
    List<CategoryBreakdown>? breakdown;
    void emit() {
      if (generation != _generation) return;
      if (total == null || received == null || span == null) return;
      if (breakdown == null) return;
      _data = _MonthData(
        month,
        total!,
        received!,
        span!.weeks,
        week?.$1,
        span!.expenses,
        breakdown!,
      );
      notifyListeners();
    }

    // The header totals follow the list range: the whole month, or the chosen full week.
    final e = _s.expenses;
    _monthSubs = [
      e.watchTotalForRange(listStart, listEnd).listen((v) {
        total = v;
        emit();
      }),
      e.watchReceivedForRange(listStart, listEnd).listen((v) {
        received = v;
        emit();
      }),
      e
          .watchInRange(spanStart, spanEnd)
          .asyncMap((list) async {
            final weeks = await e.weekSummariesForMonth(year, month0);
            return (
              weeks: weeks,
              expenses: [
                for (final x in list)
                  if (x.notificationPostTime >= listStart &&
                      x.notificationPostTime < listEnd)
                    x,
              ],
            );
          })
          .listen((v) {
            span = v;
            emit();
          }),
      e.watchCategoryBreakdown(listStart, listEnd).listen((v) {
        breakdown = v;
        emit();
      }),
    ];
  }

  void _watchAllTime() {
    final e = _s.expenses;
    _allTimeSubs = [
      e.watchTotalForRange(0, _forever).listen((v) {
        _allTimeTotal = v;
        notifyListeners();
      }),
      e.watchCategoryBreakdown(0, _forever).listen((v) {
        _allTimeBreakdown = v;
        notifyListeners();
      }),
    ];
  }

  void _rebuildAll() {
    final expenses = _allActive;
    final months = _monthly;
    if (!_s.activitySelection.value.showAll ||
        expenses == null ||
        months == null) {
      _allMonths = null;
      return;
    }
    final filter = _s.activitySelection.value.categoryFilter;
    final byMonth = {
      for (final m in months) YearMonth(m.year, m.month0 + 1): m,
    };
    final groups = <YearMonth, List<Expense>>{};
    for (final x in expenses) {
      if (!matchesCategory(x, filter)) continue;
      final d = DateTime.fromMillisecondsSinceEpoch(x.notificationPostTime);
      groups.putIfAbsent(YearMonth(d.year, d.month), () => []).add(x);
    }
    _allMonths = [
      for (final MapEntry(:key, :value) in groups.entries)
        ActivityMonthGroup(
          key,
          byMonth[key]?.total ?? Decimal.zero,
          byMonth[key]?.received ?? Decimal.zero,
          value,
        ),
    ];
  }

  static void _cancelAll(List<StreamSubscription<Object?>> subs) {
    for (final sub in subs) {
      sub.cancel();
    }
  }

  // Stepping inside the tab keeps the category filter. Only the deep link of Home clears it.
  void previousMonth() {
    final sel = _s.activitySelection.value;
    _s.activitySelection.show(
      MonthNav.previous(sel.month),
      categoryFilter: sel.categoryFilter,
    );
  }

  void nextMonth() {
    final sel = _s.activitySelection.value;
    final next = MonthNav.next(sel.month, _currentMonth);
    if (next != null) {
      _s.activitySelection.show(next, categoryFilter: sel.categoryFilter);
    }
  }

  void pickMonth(YearMonth month) => _s.activitySelection.show(
    month,
    categoryFilter: _s.activitySelection.value.categoryFilter,
  );

  void toggleWeek(int weekStart) {
    final sel = _s.activitySelection.value;
    _s.activitySelection.show(
      sel.month,
      weekStart: sel.weekStart == weekStart ? null : weekStart,
      categoryFilter: sel.categoryFilter,
    );
  }

  void setCategoryFilter(String? filter) =>
      _s.activitySelection.setCategoryFilter(filter);

  void setShowAll(bool value) => _s.activitySelection.setShowAll(value);

  String categoryNameFor(Expense e) {
    for (final c in _categories) {
      if (c.id == e.categoryId) return c.name;
    }
    return CategoryRepository.uncategorizedName;
  }

  @override
  void dispose() {
    _s.activitySelection.removeListener(_onSelection);
    _cancelAll(_subs);
    _cancelAll(_monthSubs);
    _cancelAll(_allTimeSubs);
    super.dispose();
  }
}
